\ JULIAV444-CORE20.fth — Julia and Mandelbrot on twenty tasks and ten processors
\
\ Jos v.d. Ven, Win32Forth, public domain. The z^2+c formula is
\ Marcel Hendrix, iForth, April 1994. This copy draws into the
\ TRUECOLOR graphics window. JULIAV444.fth is the one-thread copy.
\
\ Load:
\   FROMLIB FLOAD Juliav444/JULIAV444-CORE20.fth
\   JULIAV444-CORE20
\
\ Pixels use Library/FixPoint at the default 28 fraction bits.
\ X*, cell + and -, and 2* are the inner loop. XSIN and XCOS are
\ the snake and tentacle steps. Their constants are for 28 bits,
\ so this file does not set XBITS. About twenty zooms in from the
\ opening view the per-pixel step no longer fits, and that zoom
\ is refused. Color sines are the original degree table.
\
\ Julia arrows slide the picture with the key. Up and Down
\ change fposy, the vertical complex coordinate. Left and Right
\ change fposx, the horizontal one. Shift-Up zooms in on the
\ vertical axis, Shift-Down zooms out. Shift-Right zooms in on
\ the horizontal axis, Shift-Left zooms out. The Win32 walker
\ had those axes swapped.
\
\ Mandelbrot arrows move the window through the plane. Up and
\ Left add the step to both ends. Down and Right subtract it.
\ The picture therefore slides against the vertical arrows.
\ Shift-Right and Shift-Up move both ends inward. Shift-Left
\ and Shift-Down zoom that axis out.
\
\ A left click centers that pixel and zooms both axes in by 2.
\ Option-click does the same and zooms out by 2. The host ORs
\ 1024 into the (APP-MOUSE) button mask while Option is down.
\ Zoom-in stops when the fixed step for one pixel becomes 0.
\
\ R starts random slides. Space does not stop the frame in
\ progress. It holds that picture when the refresh finishes.
\ After each slide the next one waits JV-WAIT milliseconds,
\ 2000 at load, so a fast frame can still be paused. S saves
\ the finished frame. Any other key still stops the pass.
\ Esc or Q returns to the console.
\ V cycles four saved views.
\
\ Ten processors, 64Forth.core.0 through 64Forth.core.9.
\ This Mac has 4 performance cores and 6 efficiency cores.
\ Twenty tasks own twenty column bands. The first ten start
\ at once. Each later task waits. The processor that finishes
\ takes the oldest waiting task, so a performance core can
\ complete two or more bands while an efficiency core is still
\ on its first. The console stays on 64Forth.kernel. The tasks
\ do not PAUSE. xx, yy,
\ and the other pixel temps live in that task's PAD, because
\ a dictionary VARIABLE is one shared cell. PREFRESH, keys,
\ and the mouse stay on the console. CORES-JOIN returns
\ before the next frame's ACTIVATE. A click sets the abort
\ cell at once. The wait for the button to come up runs
\ after that join, so one held click is one zoom. COOP runs
\ on the way out. S saves the picture as JPEG, PNG, or TIFF.
\ Ini files and sound are not in this copy.
\
\ The hot step is the same shift as X*. It is not a CODE word.
\   x0 = x, x1 = y, x8 = aa, x9 = bb, x7 = 100 in Q28
\   mul   x4, x0, x0          smulh x5, x0, x0
\   lsr   x4, x4, #28         lsl   x5, x5, #36
\   orr   x2, x4, x5          ; x^2   (bias the 128-bit product
\   mul   x4, x1, x1          smulh x5, x1, x1    if smulh < 0)
\   lsr   x4, x4, #28         lsl   x5, x5, #36
\   orr   x3, x4, x5          ; y^2
\   add   x6, x2, x3          cmp   x6, x7
\   b.gt  escape
\   sub   x2, x2, x3          add   x0, x2, x8    ; x'
\   mul   x4, x0s, x1s        smulh x5, x0s, x1s  ; old x, y
\   lsr   x4, x4, #28         lsl   x5, x5, #36
\   orr   x4, x4, x5          lsl   x1, x4, #1
\   add   x1, x1, x9          ; y' = 2*x*y + bb
\
\ Public domain.

[DEFINED] ANEW [IF] ANEW JULIAV444-CORE20-MODULE [THEN]
[DEFINED] EMIT-NO-WRAPPER [IF] EMIT-NO-WRAPPER [THEN]

ONLY FORTH DEFINITIONS
DECIMAL

\ Console text. GRAPHICS ." and CR draw into the window.
: JV-LINE ( c-addr u -- ) TYPE CR ;

[UNDEFINED] FIXED-POINT [IF]
  FROMLIB FLOAD FixPoint/FIXEDPOINT.fth
[ELSE]
  ONLY FORTH ALSO FIXED-POINT
  XBITS 28 <> IF
    S" JULIAV444-CORE20: XSIN and XCOS are built for 28 fraction bits." JV-LINE
    S" This session has another XBITS. Trig expects 28." JV-LINE
  THEN
[THEN]

ONLY FORTH DEFINITIONS
ALSO FLOATING ALSO FIXED-POINT ALSO GRAPHICS
DECIMAL

0.1e0 F>X CONSTANT JV-A0
1.0e0 F>X CONSTANT JV-B0
1.9e0 F>X CONSTANT JV-P1
2.0e0 F>X CONSTANT JV-P2
100.0e0 F>X CONSTANT JV-100
14.0e0 F>X CONSTANT JV-14
4.0e0 F>X CONSTANT JV-4
1.0e0 F>X CONSTANT JV-ONE
1.2e0 F>X CONSTANT JV-12
1.3e0 F>X CONSTANT JV-13
10.0e0 F>X CONSTANT JV-TEN
0.1e0 F>X CONSTANT JV-TENTH

16777216 CONSTANT JV-24

VARIABLE JV-AA
VARIABLE JV-BB
VARIABLE JV-JDET
VARIABLE JV-MDET
VARIABLE JV-FZPX
VARIABLE JV-FZPY
VARIABLE JV-FPOSX
VARIABLE JV-FPOSY
VARIABLE JV-FDIST
VARIABLE JV-FZDIST
VARIABLE JV-MAXX
VARIABLE JV-MINX
VARIABLE JV-MAXY
VARIABLE JV-MINY
VARIABLE JV-DIST
VARIABLE JV-PAT
VARIABLE JV-MDIST
VARIABLE JV-CF
VARIABLE JV-CT
VARIABLE JV-STEP
VARIABLE JV-INC
VARIABLE JV-MAN
VARIABLE JV-SID
VARIABLE JV-TIG
\ Per-task pixel state. PAD is 1024 bytes and belongs to the
\ running task. Twenty tasks writing one VARIABLE would race.
: JV-XX ( -- addr ) PAD ;
: JV-YY ( -- addr ) PAD CELL+ ;
: JV-TMP ( -- addr ) PAD 2 CELLS + ;
: JV-A ( -- addr ) PAD 3 CELLS + ;
: JV-B ( -- addr ) PAD 4 CELLS + ;
: JV-CA ( -- addr ) PAD 5 CELLS + ;
: JV-CB ( -- addr ) PAD 6 CELLS + ;
VARIABLE JV-N1
VARIABLE JV-N2
VARIABLE JV-XM
VARIABLE JV-YM
VARIABLE JV-DX
VARIABLE JV-DY
VARIABLE JV-ABORT
VARIABLE JV-QUIT
VARIABLE JV-PEND
VARIABLE JV-SHOW
VARIABLE JV-HOLD
VARIABLE JV-WAIT  2000 JV-WAIT !
VARIABLE JV-RESIZE
VARIABLE JV-NCOLS
VARIABLE JV-NROWS
VARIABLE JV-MX
VARIABLE JV-MY
VARIABLE JV-MB
VARIABLE JV-HIT
VARIABLE JV-T0
VARIABLE JV-MS
VARIABLE JV-RND
VARIABLE JV-PRE
VARIABLE JV-BAD

DEFER JV-PIXEL

\ Win32 RGB is 0x00BBGGRR. r is the low byte.
: JV-RGB ( r g b -- cref )
  256 * + 256 * + ;

\ COLORREF 0x00BBGGRR to TRUECOLOR $AARRGGBB, stored with L!.
: JV-PEN ( cref -- bgra )
  DUP 255 AND 16 LSHIFT
  OVER 8 RSHIFT 255 AND 8 LSHIFT OR
  SWAP 16 RSHIFT 255 AND OR
  $FF000000 OR ;

: JV-PICK ( n -- cref )
  $FFFFFF AND ;

: JV-DOT ( x y cref -- )
  JV-PEN >R
  G-PIX 0= IF 2DROP R> DROP EXIT THEN
  2DUP XY-OK? IF
    XY>ADDR R> SWAP L!
  ELSE
    2DROP R> DROP
  THEN ;

: JV-+RGB ( cref add -- cref )
  >R
  JV-INC @ 1 AND IF R@ + THEN
  JV-INC @ 2 AND IF R@ 8 LSHIFT + THEN
  JV-INC @ 4 AND IF R@ 16 LSHIFT + THEN
  R> DROP ;

\ Integer part of a fixed value, toward zero.
: JV-X>S ( x -- n )
  S>D XUNIT SM/REM NIP ;

\ tan(x) = sin/cos. A zero cosine returns 0.
: JV-XTAN ( x -- tan )
  DUP XSIN SWAP XCOS
  DUP 0= IF 2DROP 0 EXIT THEN
  X/ ;

\ Degree table, values times 100000. Coloring only.
CREATE JV-SINUS
     0 ,  1745 ,  3490 ,  5234 ,  6976 ,  8716 , 10453 , 12187 , 13917 ,
 15643 , 17365 , 19081 , 20791 , 22495 , 24192 , 25882 , 27564 , 29237 ,
 30902 , 32567 , 34202 , 35837 , 37461 , 39073 , 40674 , 42262 , 43837 ,
 45399 , 46947 , 48481 , 50000 , 51504 , 52992 , 54464 , 55919 , 57358 ,
 58779 , 60182 , 61566 , 62932 , 64279 , 65606 , 66913 , 68200 , 69466 ,
 70711 , 71934 , 73135 , 74314 , 75471 , 76604 , 77715 , 78801 , 79864 ,
 80902 , 81915 , 82904 , 83867 , 84805 , 85717 , 86603 , 87462 , 88295 ,
 89101 , 89879 , 90631 , 91355 , 92050 , 92718 , 93358 , 93969 , 94552 ,
 95106 , 95630 , 96126 , 96593 , 97030 , 97437 , 97815 , 98163 , 98481 ,
 98769 , 99027 , 99255 , 99452 , 99619 , 99756 , 99863 , 99939 , 99985 ,
100000 ,

: JV-SIN@ ( deg -- n )
  0 MAX 90 MIN CELLS JV-SINUS + @ ;

: JV-ISIN ( angle -- n )
  DUP ABS
  DUP 360 > IF 360 MOD THEN
  DUP 91 < IF
    JV-SIN@
  ELSE DUP 181 < IF
    180 - ABS JV-SIN@
  ELSE DUP 271 < IF
    180 - JV-SIN@ NEGATE
  ELSE
    360 - ABS JV-SIN@ NEGATE
  THEN THEN THEN
  SWAP 0< IF NEGATE THEN ;

: JV-ICOS ( angle -- n )
  90 - DUP 0> >R
  ABS JV-ISIN
  R> IF NEGATE THEN ;

: JV-MAG ( -- mag )
  JV-XX @ DUP X* JV-YY @ DUP X* + ;

\ y' is stored. x' is left. The cross term uses the old pair.
: JV-Z2 ( -- x' )
  JV-XX @ DUP X* JV-YY @ DUP X* - JV-AA @ +
  >R
  JV-XX @ JV-YY @ X* 2* JV-BB @ + JV-YY !
  R> ;

: JV-STD ( -- color )
  JV-JDET @ 30 + 0 DO
    JV-MAG DUP JV-100 > IF
      DROP
      JV-YY @ 0> IF
        I 276400 * JV-CT @ +
      ELSE
        I 276400 * JV-CF @ +
      THEN
      JV-PICK UNLOOP EXIT
    THEN
    DROP
    JV-Z2 JV-XX !
  LOOP
  0 ;

: JV-ANTI ( -- color )
  JV-JDET @ 9 + 0 DO
    JV-MAG DUP JV-100 > IF
      DROP
      JV-YY @ 0> IF
        I JV-CT @ +
      ELSE
        I JV-CF @ +
      THEN
      500000 * JV-TMP !
      LEAVE
    THEN
    DROP
    JV-Z2 DUP JV-X>S JV-TMP ! JV-XX !
  LOOP
  JV-TMP @ JV-CF @ + 809000 * JV-PICK ;

: JV-EXT ( -- color )
  JV-JDET @ 9 + 0 DO
    JV-MAG DUP JV-100 > IF
      JV-YY @ 0> IF
        JV-CT @ SWAP JV-X>S JV-+RGB
      ELSE
        JV-CF @ SWAP JV-X>S NEGATE JV-+RGB
      THEN
      JV-PICK UNLOOP EXIT
    THEN
    DROP
    JV-Z2 DUP JV-TMP ! JV-XX !
  LOOP
  JV-CF @ JV-CT @ +
  JV-TMP @ JV-X>S ABS 2* NEGATE
  JV-+RGB JV-PICK ;

: JV-EXTA ( -- color )
  JV-JDET @ 9 + 0 DO
    JV-MAG DUP JV-100 > IF
      JV-YY @ 0> IF
        JV-CT @ SWAP JV-X>S NEGATE JV-+RGB
      ELSE
        JV-CF @ SWAP JV-X>S JV-+RGB
      THEN
      JV-PICK UNLOOP EXIT
    THEN
    DROP
    JV-Z2 DUP JV-TMP ! JV-XX !
  LOOP
  JV-TMP @ JV-X>S JV-CF @ + 800000 * JV-PICK ;

\ Bailout is square root. The iterate is still z^2+c.
\ The Win32 colon word fsqr was FSQRT, compiled after the
\ code words, so only this test changed.
: JV-CAM ( -- color )
  JV-JDET @ 9 + 0 DO
    JV-XX @ XSQRT JV-YY @ XSQRT +
    DUP JV-X>S JV-ISIN 292 / I + JV-TMP !
    JV-100 > IF
      JV-YY @ 0> IF
        JV-TMP @ JV-CT @ + 100000 *
      ELSE
        JV-TMP @ JV-CF @ + 100000 *
      THEN
      JV-PICK UNLOOP EXIT
    THEN
    JV-Z2 DUP XSIN JV-XTAN JV-X>S 9 * JV-TMP ! JV-XX !
  LOOP
  JV-TMP @ JV-CF @ + 800000 * JV-PICK ;

\ tan(sin(mag^2 * x)), then the square step.
: JV-TIGP ( -- color )
  JV-JDET @ 9 + 0 DO
    JV-MAG
    DUP DUP X* JV-XX @ X*
    XSIN JV-XTAN JV-X>S JV-CF @ * JV-TMP !
    \ > already consumed the magnitude.
    JV-100 > IF
      JV-TMP @ S>D JV-24 SM/REM DROP
      JV-CT @ * 3000 * JV-CF @ +
      JV-PICK UNLOOP EXIT
    THEN
    DROP
    JV-Z2 DUP XSIN JV-XTAN JV-X>S I * 3000 * JV-TMP ! JV-XX !
  LOOP
  JV-TMP @ JV-CT @ + JV-PICK ;

: JV-SNAKE? ( -- flag )
  JV-MAG
  DUP 100 * JV-X>S JV-TMP !
  JV-14 > ;

: JV-SNAKE-STEP ( -- )
  JV-XX @ XSIN JV-YY @ XCOS - JV-AA @ +
  >R
  JV-XX @ JV-YY @ X* 2* JV-BB @ + JV-YY !
  R> JV-XX ! ;

: JV-SNAKE ( -- color )
  JV-JDET @ 20 + 0 DO
    JV-SNAKE? IF
      I JV-TMP @ +
      I JV-STEP @ * 85000 *
      JV-YY @ 0> IF
        +
        I NEGATE JV-+RGB
        JV-CT @ +
      ELSE
        -
        I JV-+RGB
        JV-CF @ +
      THEN
      JV-PICK UNLOOP EXIT
    THEN
    JV-SNAKE-STEP
  LOOP
  JV-TMP @ JV-CF @ + JV-STEP @ * 17000 * NEGATE
  JV-PICK ;

: JV-TENT-STEP ( -- )
  JV-XX @ XSIN JV-YY @ JV-XTAN - JV-AA @ +
  DUP JV-X>S JV-TMP !
  >R
  JV-XX @ JV-YY @ X* 2* JV-BB @ + JV-YY !
  R> JV-XX ! ;

: JV-TENT ( -- color )
  JV-JDET @ 20 + 0 DO
    JV-MAG
    DUP 1001 * JV-X>S I + JV-TMP !
    JV-14 > IF
      JV-YY @ 0> IF
        JV-TMP @ JV-CT @ +
      ELSE
        JV-TMP @ JV-CF @ +
      THEN
      JV-PICK UNLOOP EXIT
    THEN
    JV-TENT-STEP
  LOOP
  JV-TMP @ 30000 * JV-CF @ + JV-PICK ;

: JV-USE ( sid xt -- )
  IS JV-PIXEL
  JV-SID !
  0 JV-MAN ! ;

: JV-STYLE ( n -- )
  DUP 2 /MOD DROP -
  DUP 0 = IF DROP 0 ['] JV-STD JV-USE EXIT THEN
  DUP 2 = IF DROP 1 ['] JV-ANTI JV-USE EXIT THEN
  DUP 4 = IF DROP 2 ['] JV-EXT JV-USE EXIT THEN
  DUP 8 = IF DROP 3 ['] JV-EXTA JV-USE EXIT THEN
  DUP 16 = IF DROP 4 ['] JV-CAM JV-USE EXIT THEN
  DUP 32 = IF DROP 5 ['] JV-TIGP JV-USE EXIT THEN
  DUP 64 = IF DROP 6 ['] JV-SNAKE JV-USE EXIT THEN
  DUP 128 = IF DROP 7 ['] JV-TENT JV-USE EXIT THEN
  DROP 4 ['] JV-CAM JV-USE ;

: JV-M-ITER ( -- color )
  JV-CA @ JV-A !
  JV-CB @ JV-B !
  JV-MDET @ 3 MAX 0 DO
    JV-A @ DUP X* JV-B @ DUP X* 2DUP +
    JV-4 > IF
      2DROP
      I 80431637 * JV-CF @ +
      JV-PICK UNLOOP EXIT
    THEN
    - JV-CA @ + JV-DIST @ X* >R
    JV-A @ JV-B @ X* 2* JV-CB @ + JV-B !
    R> JV-A !
  LOOP
  JV-TIG @ 0= IF 0 EXIT THEN
  JV-A @ JV-B @ X*
  JV-PAT @ DUP DUP * *
  JV-PAT @ 10 / +
  *
  JV-X>S JV-ICOS
  500 / 7 * ABS
  JV-CT @ *
  JV-PICK ;

: JV-MAP ( -- )
  G-PX 2/ 1 MAX DUP JV-XM ! JV-N1 !
  G-PY 2/ 1 MAX JV-YM !
  JV-N1 @ JV-P1 X* JV-P2 X/ DUP 1 < IF DROP 1 THEN JV-N2 ! ;

: JV-M-SETUP ( -- )
  G-PX 1 MAX
  JV-MAXX @ JV-MINX @ - SWAP / JV-DX !
  G-PY 1 MAX
  JV-MAXY @ JV-MINY @ - SWAP / JV-DY ! ;

\ Left button, with Option in bit 1024. Wait until it is up so
\ one click is one zoom. (APP-MOUSE) is x y buttons.
: JV-MDOWN ( -- flag )
  (APP-MOUSE)
  DUP 1 AND 0= IF DROP 2DROP FALSE EXIT THEN
  JV-MB ! JV-MY ! JV-MX !
  BEGIN
    PAUSE
    (APP-MOUSE) NIP NIP 0=
  UNTIL
  TRUE ;

: JV-POLL ( -- flag )
  KEY? IF
    KEY
    DUP BL = IF
      DROP
      JV-SHOW @ IF -1 JV-HOLD ! THEN
      FALSE EXIT
    THEN
    DUP [CHAR] s = OVER [CHAR] S = OR IF
      JV-PEND !
      FALSE EXIT
    THEN
    JV-PEND !
    -1 JV-ABORT !
    TRUE EXIT
  THEN
  JV-MDOWN IF
    -1 JV-HIT !
    -1 JV-ABORT !
    TRUE EXIT
  THEN
  (APP-SIZE?) IF
    JV-NROWS ! JV-NCOLS !
    -1 JV-RESIZE !
    -1 JV-ABORT !
    TRUE EXIT
  THEN
  2DROP
  FALSE ;

: JV-APPLY ( -- )
  JV-RESIZE @ IF
    0 JV-RESIZE !
    JV-NCOLS @ JV-NROWS @ WINDOW-SIZE
  ELSE
    (APP-SIZE?) IF WINDOW-SIZE ELSE 2DROP THEN
  THEN ;

: JV-JPIX ( x y -- )
  2DUP
  JV-YM @ - >R
  JV-XM @ -
  JV-N2 @ 0= IF DROP R> DROP 2DROP EXIT THEN
  DUP JV-P2 * JV-N2 @ / JV-FZPX @ X* JV-FPOSX @ + JV-YY !
  R> JV-P1 * JV-N1 @ / JV-FZPY @ X* JV-FPOSY @ + JV-XX !
  DROP
  JV-PIXEL
  JV-DOT ;

\ LEAVE scans forward to the next (LOOP) in this word. The row
\ walk is its own word, so an abort leaves this column. A row
\ LOOP in the band word would make LEAVE drop the band frame.
\ No PAUSE here. A worker runs until STOP.
: JV-COL-J ( x -- )
  G-PY 0 DO
    JV-ABORT @ IF LEAVE THEN
    DUP I JV-JPIX
  LOOP
  DROP ;

: JV-MPIX ( x y -- )
  2DUP
  JV-DY @ * JV-MINY @ + JV-CB !
  JV-DX @ * JV-MINX @ + JV-CA !
  JV-M-ITER
  JV-DOT ;

: JV-COL-M ( x -- )
  G-PY 0 DO
    JV-ABORT @ IF LEAVE THEN
    DUP I JV-MPIX
  LOOP
  DROP ;

\ Column bands. lo and hi are clamped so an empty band is
\ lo = hi, and ?DO does not run backwards. Band 19 keeps the
\ remainder, so the last column is always inside a band.
20 CONSTANT JV-NTASK
10 CONSTANT JV-NCPU
CREATE JV-LO 20 CELLS ALLOT
CREATE JV-HI 20 CELLS ALLOT
CREATE JV-DN 20 CELLS ALLOT
VARIABLE JV-SPAN

: JV-PAIR ( lo span -- lo hi )
  OVER + G-PX MIN
  SWAP G-PX MIN SWAP ;

\ Span stays in JV-SPAN. R@ inside the DO would be the loop index.
\ The offset is saved in JV-PUT, which is not inside that DO.
: JV-PUT ( lo hi i -- )
  CELLS >R
  R@ JV-HI + !
  R> JV-LO + ! ;

: JV-SPLIT ( -- )
  G-PX JV-NTASK / DUP 0= IF DROP 1 THEN JV-SPAN !
  JV-NTASK 0 DO
    I JV-NTASK 1- = IF
      JV-SPAN @ JV-NTASK 1- * G-PX MIN G-PX
    ELSE
      I JV-SPAN @ * JV-SPAN @ JV-PAIR
    THEN
    I JV-PUT
  LOOP ;

\ The done cell is stored after LEAVE, then STOP. The console
\ does not ACTIVATE again until CORES-JOIN has returned.
: JV-BAND-J ( x0 x1 done -- )
  >R
  SWAP
  ?DO
    JV-ABORT @ IF LEAVE THEN
    I JV-COL-J
  LOOP
  -1 R> !
  STOP ;

: JV-BAND-M ( x0 x1 done -- )
  >R
  SWAP
  ?DO
    JV-ABORT @ IF LEAVE THEN
    I JV-COL-M
  LOOP
  -1 R> !
  STOP ;

: JV-WORK ( n -- )
  CELLS >R
  JV-LO R@ + @
  JV-HI R@ + @
  JV-DN R> +
  JV-MAN @ IF JV-BAND-M ELSE JV-BAND-J THEN ;
TASK: JV-T00
TASK: JV-T01
TASK: JV-T02
TASK: JV-T03
TASK: JV-T04
TASK: JV-T05
TASK: JV-T06
TASK: JV-T07
TASK: JV-T08
TASK: JV-T09
TASK: JV-T10
TASK: JV-T11
TASK: JV-T12
TASK: JV-T13
TASK: JV-T14
TASK: JV-T15
TASK: JV-T16
TASK: JV-T17
TASK: JV-T18
TASK: JV-T19

: JV-GO00 ( -- ) JV-T00 ACTIVATE 0 JV-WORK ;
: JV-GO01 ( -- ) JV-T01 ACTIVATE 1 JV-WORK ;
: JV-GO02 ( -- ) JV-T02 ACTIVATE 2 JV-WORK ;
: JV-GO03 ( -- ) JV-T03 ACTIVATE 3 JV-WORK ;
: JV-GO04 ( -- ) JV-T04 ACTIVATE 4 JV-WORK ;
: JV-GO05 ( -- ) JV-T05 ACTIVATE 5 JV-WORK ;
: JV-GO06 ( -- ) JV-T06 ACTIVATE 6 JV-WORK ;
: JV-GO07 ( -- ) JV-T07 ACTIVATE 7 JV-WORK ;
: JV-GO08 ( -- ) JV-T08 ACTIVATE 8 JV-WORK ;
: JV-GO09 ( -- ) JV-T09 ACTIVATE 9 JV-WORK ;
: JV-GO10 ( -- ) JV-T10 ACTIVATE 10 JV-WORK ;
: JV-GO11 ( -- ) JV-T11 ACTIVATE 11 JV-WORK ;
: JV-GO12 ( -- ) JV-T12 ACTIVATE 12 JV-WORK ;
: JV-GO13 ( -- ) JV-T13 ACTIVATE 13 JV-WORK ;
: JV-GO14 ( -- ) JV-T14 ACTIVATE 14 JV-WORK ;
: JV-GO15 ( -- ) JV-T15 ACTIVATE 15 JV-WORK ;
: JV-GO16 ( -- ) JV-T16 ACTIVATE 16 JV-WORK ;
: JV-GO17 ( -- ) JV-T17 ACTIVATE 17 JV-WORK ;
: JV-GO18 ( -- ) JV-T18 ACTIVATE 18 JV-WORK ;
: JV-GO19 ( -- ) JV-T19 ACTIVATE 19 JV-WORK ;

: JV-DONE? ( -- flag )
  -1
  JV-NTASK 0 DO
    JV-DN I CELLS + @ AND
  LOOP ;

: JV-CLEAR-DONE ( -- )
  JV-DN JV-NTASK CELLS 0 FILL ;

\ Keys and the mouse. Space holds the slideshow and does not
\ abort. S stores the key and does not abort, so the save
\ runs after the frame. Any other key, a left click, or a
\ resize stops the workers. The button-up wait is not here:
\ it would keep this task in the frame while the next zoom
\ is not yet allowed.
: JV-LISTEN ( -- )
  KEY? IF
    KEY
    DUP BL = IF
      DROP
      JV-SHOW @ IF -1 JV-HOLD ! THEN
      EXIT
    THEN
    DUP [CHAR] s = OVER [CHAR] S = OR IF
      JV-PEND !
      EXIT
    THEN
    JV-PEND !
    -1 JV-ABORT !
    EXIT
  THEN
  (APP-MOUSE)
  DUP 1 AND IF
    JV-MB ! JV-MY ! JV-MX !
    -1 JV-HIT !
    -1 JV-ABORT !
    EXIT
  THEN
  DROP 2DROP
  (APP-SIZE?) IF
    JV-NROWS ! JV-NCOLS !
    -1 JV-RESIZE !
    -1 JV-ABORT !
  ELSE
    2DROP
  THEN ;

: JV-CORES-WAIT ( -- )
  MS@
  BEGIN
    JV-DONE? IF DROP EXIT THEN
    MS@ OVER - 100 > IF
      PREFRESH
      DROP MS@
    THEN
    JV-LISTEN
    PAUSE
  AGAIN ;

: JV-LAUNCH ( -- )
  JV-SPLIT
  JV-CLEAR-DONE
  SINGLE
  CORES
  JV-GO00 JV-GO01 JV-GO02 JV-GO03
  JV-GO04 JV-GO05 JV-GO06 JV-GO07
  JV-GO08 JV-GO09 JV-GO10 JV-GO11
  JV-GO12 JV-GO13 JV-GO14 JV-GO15
  JV-GO16 JV-GO17 JV-GO18 JV-GO19
  JV-CORES-WAIT
  CORES-JOIN ;

: JV-DRAW-J ( -- )
  JV-MAP
  PIX-ERASE
  JV-LAUNCH ;

: JV-DRAW-M ( -- )
  JV-M-SETUP
  PIX-ERASE
  JV-LAUNCH ;

: JV-SNAME ( -- c-addr u )
  JV-MAN @ IF S" Mandelbrot" EXIT THEN
  JV-SID @
  DUP 0 = IF DROP S" standard" EXIT THEN
  DUP 1 = IF DROP S" anti-julia" EXIT THEN
  DUP 2 = IF DROP S" extreme" EXIT THEN
  DUP 3 = IF DROP S" extreme-anti" EXIT THEN
  DUP 4 = IF DROP S" cameleon" EXIT THEN
  DUP 5 = IF DROP S" tiger" EXIT THEN
  DUP 6 = IF DROP S" snake" EXIT THEN
  DROP S" tentacle" ;

CREATE JV-TBUF 160 ALLOT
VARIABLE JV-TL

: JV-TCLR ( -- ) 0 JV-TL ! ;

: JV-T+ ( c-addr u -- )
  DUP JV-TL @ + 150 > IF 2DROP EXIT THEN
  >R JV-TBUF JV-TL @ + R@ MOVE
  R> JV-TL +! ;

: JV-TDOT ( n -- )
  DUP 0< IF
    NEGATE S" -" JV-T+
  THEN
  0 <# #S #> JV-T+ ;

: JV-TITLE ( -- )
  JV-TCLR
  S" JULIAV444-CORE20 " JV-T+
  JV-SNAME JV-T+
  S"  " JV-T+
  JV-MAN @ IF JV-MDET @ ELSE JV-JDET @ THEN JV-TDOT
  S"  " JV-T+
  JV-MS @ JV-TDOT
  S" ms" JV-T+
  JV-TBUF JV-TL @ APP-NAME ;

\ Slideshow only. Space, or a key during this wait, holds the
\ frame that just finished. A stored key or click skips the wait.
: JV-DWELL ( -- )
  JV-SHOW @ 0= IF EXIT THEN
  JV-ABORT @ JV-PEND @ OR JV-HIT @ OR IF
    0 JV-HOLD !
    EXIT
  THEN
  JV-HOLD @ IF
    0 JV-HOLD !
    0 JV-SHOW !
    EXIT
  THEN
  JV-WAIT @ 0= IF EXIT THEN
  MS@ JV-WAIT @ +
  BEGIN
    DUP MS@ < IF DROP EXIT THEN
    KEY? IF
      KEY
      DUP BL = IF
        DROP 0 JV-SHOW ! DROP EXIT
      THEN
      JV-PEND !
      DROP EXIT
    THEN
    JV-MDOWN IF
      -1 JV-HIT !
      DROP EXIT
    THEN
    PAUSE
  AGAIN ;

: JV-DRAW ( -- )
  0 JV-ABORT !
  JV-APPLY
  MS@ JV-T0 !
  JV-MAN @ IF JV-DRAW-M ELSE JV-DRAW-J THEN
  MS@ JV-T0 @ - JV-MS !
  JV-TITLE
  PREFRESH
  JV-DWELL ;

: JV-COLORS ( -- )
  0 256 0 JV-RGB JV-CF !
  12709967 JV-CT !
  7 JV-STEP !
  7 JV-INC ! ;

: JV-HOME-J ( -- )
  JV-ONE JV-FZPX !
  JV-ONE JV-FZPY !
  0 JV-FPOSX !
  0 JV-FPOSY !
  JV-12 JV-FDIST !
  0 JV-JDET ! ;

: JV-HOME-M ( -- )
  1.02e0 F>X JV-MAXX !
  2.0e0 FNEGATE F>X JV-MINX !
  1.4e0 F>X JV-MAXY !
  1.4e0 FNEGATE F>X JV-MINY !
  30 JV-MDET !
  JV-ONE JV-DIST !
  7 JV-PAT !
  JV-TENTH JV-MDIST !
  0 JV-TIG !
  0 255 100 JV-RGB JV-CT !
  0 JV-CF ! ;

: JV-RESET ( -- )
  JV-A0 JV-AA !
  JV-B0 JV-BB !
  JV-COLORS
  JV-HOME-J
  JV-13 JV-FZDIST !
  JV-12 JV-FDIST !
  1.02e0 F>X JV-MAXX !
  2.0e0 FNEGATE F>X JV-MINX !
  1.4e0 F>X JV-MAXY !
  1.4e0 FNEGATE F>X JV-MINY !
  30 JV-MDET !
  JV-ONE JV-DIST !
  7 JV-PAT !
  JV-TENTH JV-MDIST !
  0 JV-TIG !
  0 JV-MAN !
  0 JV-SHOW !
  0 JV-HOLD !
  0 JV-HIT !
  0 JV-QUIT !
  0 JV-PEND !
  0 JV-ABORT !
  0 JV-RESIZE !
  0 ['] JV-STD JV-USE ;

: JV-SEED ( -- )
  MS@ DUP 0= IF DROP 2463534242 THEN JV-RND ! ;

: JV-RNDU ( -- u )
  JV-RND @
  DUP 13 LSHIFT XOR
  DUP 17 RSHIFT XOR
  DUP 5 LSHIFT XOR
  DUP JV-RND !
  2147483647 AND ;

: JV-BELOW ( n -- u )
  DUP 1 < IF DROP 0 EXIT THEN
  JV-RNDU SWAP MOD ;

: JV-RECOLOR ( -- )
  4 JV-BELOW 1+ 5 * JV-INC !
  256 JV-BELOW 256 JV-BELOW 256 JV-BELOW JV-RGB JV-CF !
  256 JV-BELOW 256 JV-BELOW 256 JV-BELOW JV-RGB JV-CT !
  255 JV-BELOW 1+ JV-STEP !
  2 JV-BELOW IF
    JV-CF @ JV-CT @ JV-CF ! JV-CT !
  THEN ;

: JV-RAND-C ( -- x )
  3001 JV-BELOW 1500 - XUNIT 1000 */ ;

: JV-SLIDE ( -- )
  9 JV-BELOW
  DUP 8 = IF
    DROP -1 JV-MAN !
  ELSE
    DUP
    DUP 0 = IF DROP 0 ['] JV-STD JV-USE ELSE
    DUP 1 = IF DROP 1 ['] JV-ANTI JV-USE ELSE
    DUP 2 = IF DROP 2 ['] JV-EXT JV-USE ELSE
    DUP 3 = IF DROP 3 ['] JV-EXTA JV-USE ELSE
    DUP 4 = IF DROP 4 ['] JV-CAM JV-USE ELSE
    DUP 5 = IF DROP 5 ['] JV-TIGP JV-USE ELSE
    DUP 6 = IF DROP 6 ['] JV-SNAKE JV-USE ELSE
    DROP 7 ['] JV-TENT JV-USE
    THEN THEN THEN THEN THEN THEN THEN
  THEN
  JV-RECOLOR
  JV-MAN @ 0= IF
    JV-RAND-C JV-AA !
    JV-RAND-C JV-BB !
  THEN ;

: JV-SPANX ( -- n ) JV-MAXX @ JV-MINX @ - ABS ;
: JV-SPANY ( -- n ) JV-MAXY @ JV-MINY @ - ABS ;

: JV-HSTEP ( -- n ) JV-SPANX JV-MDIST @ X* ABS ;
: JV-VSTEP ( -- n ) JV-SPANY JV-MDIST @ X* ABS ;

: JV-ZOOM-OK ( span -- flag )
  G-PX 1 MAX / 0<> ;

: JV-ZIN-M ( -- )
  JV-HSTEP DUP 0= IF DROP EXIT THEN
  JV-SPANX OVER 2* - JV-ZOOM-OK 0= IF 2DROP EXIT THEN
  DUP JV-MAXX @ SWAP - JV-MAXX !
  JV-MINX @ + JV-MINX !
  JV-VSTEP DUP 0= IF DROP EXIT THEN
  JV-SPANY OVER 2* - JV-ZOOM-OK 0= IF 2DROP EXIT THEN
  DUP JV-MAXY @ SWAP - JV-MAXY !
  JV-MINY @ + JV-MINY ! ;

: JV-ZOUT-H ( -- )
  JV-SPANX 2/
  DUP JV-MDIST @ X* 2* >R
  JV-MINX @ R@ - JV-MINX !
  JV-MAXX @ R> + JV-MAXX ! ;

: JV-ZOUT-V ( -- )
  JV-SPANY 2/
  DUP JV-MDIST @ X* 2* >R
  JV-MINY @ R@ - JV-MINY !
  JV-MAXY @ R> + JV-MAXY ! ;

: JV-ZIN-H ( -- )
  JV-HSTEP DUP 0= IF DROP EXIT THEN
  JV-SPANX OVER 2* - JV-ZOOM-OK 0= IF 2DROP EXIT THEN
  DUP JV-MAXX @ SWAP - JV-MAXX !
  JV-MINX @ + JV-MINX ! ;

: JV-ZIN-V ( -- )
  JV-VSTEP DUP 0= IF DROP EXIT THEN
  JV-SPANY OVER 2* - JV-ZOOM-OK 0= IF 2DROP EXIT THEN
  DUP JV-MAXY @ SWAP - JV-MAXY !
  JV-MINY @ + JV-MINY ! ;

: JV-SCALE ( x -- dx )
  DUP JV-FZDIST @ X* JV-TEN X/ ;

: JV-STEPX ( x -- step )
  JV-P2 X* JV-N2 @ DUP 0= IF DROP DROP 0 EXIT THEN / ;

: JV-STEPY ( y -- step )
  JV-P1 X* JV-N1 @ DUP 0= IF DROP DROP 0 EXIT THEN / ;

: JV-ZIN-X ( -- )
  JV-FZPX @ DUP JV-SCALE -
  DUP JV-STEPX 0= IF DROP EXIT THEN
  JV-FZPX ! ;

: JV-ZOUT-X ( -- )
  JV-FZPX @ DUP JV-SCALE + JV-FZPX ! ;

: JV-ZIN-Y ( -- )
  JV-FZPY @ DUP JV-SCALE -
  DUP JV-STEPY 0= IF DROP EXIT THEN
  JV-FZPY ! ;

: JV-ZOUT-Y ( -- )
  JV-FZPY @ DUP JV-SCALE + JV-FZPY ! ;

\ Keep x when doubling would wrap negative.
: JV-Z2* ( x -- x' )
  DUP 2* DUP 0> IF NIP ELSE DROP THEN ;

: JV-ZIN2 ( -- )
  JV-FZPX @ 2/ DUP JV-STEPX 0= IF DROP ELSE JV-FZPX ! THEN
  JV-FZPY @ 2/ DUP JV-STEPY 0= IF DROP ELSE JV-FZPY ! THEN ;

: JV-ZOUT2 ( -- )
  JV-FZPX @ JV-Z2* JV-FZPX !
  JV-FZPY @ JV-Z2* JV-FZPY ! ;

\ Put the clicked pixel at the center, then zoom both axes.
: JV-J-CLICK ( -- )
  JV-MAP
  JV-MY @ JV-YM @ -
  JV-P1 * JV-N1 @ / JV-FZPY @ X* JV-FPOSY +!
  JV-MX @ JV-XM @ -
  JV-P2 * JV-N2 @ / JV-FZPX @ X* JV-FPOSX +!
  JV-MB @ 1024 AND IF JV-ZOUT2 ELSE JV-ZIN2 THEN ;

\ center half -- min max. min is center-half, max is center+half.
: JV-LIM ( center half -- min max )
  2DUP + >R
  - R> ;

\ ca cb hx hy -- window centered on the click. hx and hy are
\ half the new span, so span/4 zooms in by 2.
: JV-BOX ( ca cb hx hy -- )
  >R
  ROT ROT
  R>
  JV-LIM JV-MAXY ! JV-MINY !
  SWAP
  JV-LIM JV-MAXX ! JV-MINX ! ;

\ Half the span when that still has a step, else the same span.
: JV-MIN2 ( ca cb -- )
  JV-SPANX 4 / DUP 0= IF DROP JV-SPANX 2/ THEN
  DUP 0= IF DROP 2DROP EXIT THEN
  JV-SPANY 4 / DUP 0= IF DROP JV-SPANY 2/ THEN
  DUP 0= IF DROP 2DROP DROP EXIT THEN
  JV-BOX ;

: JV-MOUT ( ca cb -- )
  JV-SPANX JV-SPANY JV-BOX ;

: JV-M-CLICK ( -- )
  JV-M-SETUP
  JV-MX @ JV-DX @ * JV-MINX @ +
  JV-MY @ JV-DY @ * JV-MINY @ +
  JV-MB @ 1024 AND IF JV-MOUT ELSE JV-MIN2 THEN ;

\ After the workers have stopped. A button that is still down
\ must come up before the next ACTIVATE, so one click zooms once.
: JV-UP ( -- )
  BEGIN
    (APP-MOUSE) NIP NIP 0= IF EXIT THEN
    PAUSE
  AGAIN ;

: JV-CLICK ( -- )
  0 JV-SHOW !
  JV-UP
  JV-APPLY
  JV-MAN @ IF JV-M-CLICK ELSE JV-J-CLICK THEN
  JV-DRAW ;

: JV-JSTEP ( -- n )
  JV-FDIST @
  JV-FZPY @ JV-FZPX @ MIN
  X* ABS ;

: JV-LETTER ( key c -- key flag )
  >R
  DUP R@ =
  OVER 32 OR R> = OR ;

: JV-SPIRAL ( -- )
  -1 JV-MAN !
  JV-ONE JV-DIST !
  280 JV-MDET !
  7 JV-PAT !
  0.758398e0 FNEGATE F>X JV-MAXX !
  0.761640e0 FNEGATE F>X JV-MINX !
  0.077458e0 F>X JV-MAXY !
  0.073837e0 F>X JV-MINY !
  JV-A0 JV-AA !
  JV-B0 JV-BB !
  0 JV-JDET !
  1 JV-STYLE
  67174400 JV-CF !
  12709967 JV-CT !
  7 JV-STEP !
  7 JV-INC !
  JV-ONE JV-FZPX !
  JV-ONE JV-FZPY !
  0 JV-FPOSY !
  0 JV-FPOSX !
  JV-12 JV-FDIST ! ;

: JV-WOW ( -- )
  0 JV-MAN !
  JV-ONE JV-DIST !
  30 JV-MDET !
  7 JV-PAT !
  1.02e0 F>X JV-MAXX !
  2.0e0 FNEGATE F>X JV-MINX !
  1.4e0 F>X JV-MAXY !
  1.4e0 FNEGATE F>X JV-MINY !
  JV-ONE JV-AA !
  0 JV-BB !
  0 JV-JDET !
  64 JV-STYLE
  70054141 JV-CF !
  67419919 JV-CT !
  131 JV-STEP !
  50 JV-INC !
  JV-ONE JV-FZPX !
  JV-ONE JV-FZPY !
  0 JV-FPOSY !
  0 JV-FPOSX !
  JV-12 JV-FDIST ! ;

: JV-HOLE ( -- )
  -1 JV-MAN !
  JV-ONE JV-DIST !
  710 JV-MDET !
  7 JV-PAT !
  0.744039e0 FNEGATE F>X JV-MAXX !
  0.744040e0 FNEGATE F>X JV-MINX !
  0.148022e0 F>X JV-MAXY !
  0.148021e0 F>X JV-MINY !
  JV-ONE JV-AA !
  1.56e0 F>X JV-BB !
  11 JV-JDET !
  1 JV-STYLE
  81177907 JV-CF !
  83014267 JV-CT !
  107 JV-STEP !
  25 JV-INC !
  0.000647e0 F>X JV-FZPX !
  0.000007e0 F>X JV-FZPY !
  0.183805e0 FNEGATE F>X JV-FPOSY !
  1.08984e0 F>X JV-FPOSX !
  JV-12 JV-FDIST ! ;

: JV-EYES ( -- )
  0 JV-MAN !
  JV-ONE JV-DIST !
  30 JV-MDET !
  7 JV-PAT !
  1.02e0 F>X JV-MAXX !
  2.0e0 FNEGATE F>X JV-MINX !
  1.4e0 F>X JV-MAXY !
  1.4e0 FNEGATE F>X JV-MINY !
  0.62e0 F>X JV-AA !
  0.38e0 F>X JV-BB !
  0 JV-JDET !
  64 JV-STYLE
  77351397 JV-CF !
  74136487 JV-CT !
  177 JV-STEP !
  75 JV-INC !
  0.423022439e0 F>X JV-FZPX !
  0.120344709e0 F>X JV-FZPY !
  0.507626927e0 F>X JV-FPOSY !
  1.59394776e0 F>X JV-FPOSX !
  0.578703704e0 F>X JV-FDIST ! ;

: JV-VIEW ( -- )
  JV-PRE @ 4 MOD
  DUP 1+ JV-PRE !
  DUP 0 = IF DROP JV-SPIRAL EXIT THEN
  DUP 1 = IF DROP JV-WOW EXIT THEN
  DUP 2 = IF DROP JV-HOLE EXIT THEN
  DROP JV-EYES ;

: JV-FACT ( -- n )
  JV-SPANX JV-SPANY + 100 / ;

\ Pale green glyphs. The panel is a darker medium green, RGB 31,122,52.
$FF1F7A34 CONSTANT JV-GREEN
VARIABLE JV-HBUF

\ Bytes of the top band behind help rows 0..12.
: JV-PB ( -- u )
  13 G-CELLH * G-PY MIN
  G-PX * 4 * ;

: JV-PANEL ( -- )
  JV-PB 0 DO
    JV-GREEN G-PIX I + L!
  4 +LOOP ;

: JV-HELP-LINES ( -- )
  1 1 AT ." JULIAV444-CORE20  20 tasks  10 cores   any key closes"
  1 3 AT ." 1 standard   2 anti-julia   3 extreme   4 extreme-anti"
  1 4 AT ." 5 cameleon   6 tiger   7 snake   8 tentacle"
  1 5 AT ." M Mandelbrot   J Julia   V saved views   R random slides"
  1 6 AT ." Space holds the finished slide. Next slide waits 2 seconds."
  1 7 AT ." Arrows slide the picture. Shift-arrows zoom that axis."
  1 8 AT ." Click zooms in at that point. Option-click zooms out."
  1 9 AT ." + - detail   PgUp PgDn step   H Home reset   X swap colors"
  1 10 AT ." Mandelbrot: B interior  C tiger  D E distort  P O pattern"
  1 11 AT ." Q or Esc returns to the console.  ? this list"
  1 12 AT ." S saves this picture. Choose JPEG, PNG, or TIFF." ;

\ Green text on a medium green band. Any key clears it and puts
\ the saved pixels back. The fractal is not redrawn.
: JV-HELP ( -- )
  0 JV-HBUF !
  G-BUF G-COLS G-ROWS * BL FILL
  G-PIX 0= JV-PB 0= OR 0= IF
    JV-PB ALLOCATE 0= IF
      DUP JV-HBUF !
      G-PIX OVER JV-PB CMOVE
      DROP
      JV-PANEL
    ELSE
      DROP
    THEN
  THEN
  JV-HELP-LINES
  PREFRESH
  KEY DROP
  JV-HBUF @ ?DUP IF
    G-PIX JV-PB CMOVE
    FREE DROP
    0 JV-HBUF !
  THEN
  G-BUF G-COLS G-ROWS * BL FILL
  PREFRESH ;

\ S opens the save panel. The file name selects JPEG, PNG, or TIFF.
FROMLIB S" Juliav444/JV-SAVE.fth" INCLUDED

: JV-CMD ( key -- )
  DUP 27 = OVER [CHAR] q = OR OVER [CHAR] Q = OR IF
    DROP -1 JV-QUIT ! EXIT
  THEN
  0 JV-SHOW !
  DUP [CHAR] ? = IF DROP JV-HELP EXIT THEN
  [CHAR] s JV-LETTER IF DROP JV-SAVE EXIT THEN
  DUP 200 = IF DROP
    JV-MAN @ IF
      JV-VSTEP DUP JV-MINY @ + JV-MINY !
      JV-MAXY @ + JV-MAXY !
    ELSE
      JV-JSTEP NEGATE JV-FPOSY +!
    THEN
    JV-DRAW EXIT
  THEN
  DUP 208 = IF DROP
    JV-MAN @ IF
      JV-VSTEP DUP NEGATE JV-MINY @ + JV-MINY !
      NEGATE JV-MAXY @ + JV-MAXY !
    ELSE
      JV-JSTEP JV-FPOSY +!
    THEN
    JV-DRAW EXIT
  THEN
  DUP 203 = IF DROP
    JV-MAN @ IF
      JV-HSTEP DUP JV-MINX @ + JV-MINX !
      JV-MAXX @ + JV-MAXX !
    ELSE
      JV-JSTEP JV-FPOSX +!
    THEN
    JV-DRAW EXIT
  THEN
  DUP 205 = IF DROP
    JV-MAN @ IF
      JV-HSTEP DUP NEGATE JV-MINX @ + JV-MINX !
      NEGATE JV-MAXX @ + JV-MAXX !
    ELSE
      JV-JSTEP NEGATE JV-FPOSX +!
    THEN
    JV-DRAW EXIT
  THEN
  DUP 456 = IF DROP
    JV-MAN @ IF JV-ZIN-V ELSE JV-ZIN-Y THEN
    JV-DRAW EXIT
  THEN
  DUP 464 = IF DROP
    JV-MAN @ IF JV-ZOUT-V ELSE JV-ZOUT-Y THEN
    JV-DRAW EXIT
  THEN
  DUP 459 = IF DROP
    JV-MAN @ IF JV-ZOUT-H ELSE JV-ZOUT-X THEN
    JV-DRAW EXIT
  THEN
  DUP 461 = IF DROP
    JV-MAN @ IF JV-ZIN-H ELSE JV-ZIN-X THEN
    JV-DRAW EXIT
  THEN
  DUP 199 = OVER [CHAR] h = OR OVER [CHAR] H = OR IF DROP
    JV-MAN @ IF JV-HOME-M ELSE JV-HOME-J THEN
    JV-DRAW EXIT
  THEN
  DUP 201 = IF DROP
    JV-MAN @ IF
      JV-MDIST @ JV-13 X* JV-MDIST !
    ELSE
      JV-FZDIST @ JV-12 X* JV-FZDIST !
      JV-FDIST @ JV-12 X* JV-FDIST !
    THEN
    JV-DRAW EXIT
  THEN
  DUP 209 = IF DROP
    JV-MAN @ IF
      JV-MDIST @ JV-ONE X* JV-13 X/ JV-MDIST !
    ELSE
      JV-FZDIST @ JV-ONE X* JV-12 X/ JV-FZDIST !
      JV-FDIST @ JV-ONE X* JV-12 X/ JV-FDIST !
    THEN
    JV-DRAW EXIT
  THEN
  DUP [CHAR] + = OVER [CHAR] = = OR IF DROP
    JV-MAN @ IF
      JV-MDET @ 10 + 400 MIN JV-MDET !
    ELSE
      JV-JDET @ 1+ 80 MIN JV-JDET !
    THEN
    JV-DRAW EXIT
  THEN
  DUP [CHAR] - = OVER [CHAR] _ = OR IF DROP
    JV-MAN @ IF
      JV-MDET @ 10 - 3 MAX JV-MDET !
    ELSE
      JV-JDET @ 1- 0 MAX JV-JDET !
    THEN
    JV-DRAW EXIT
  THEN
  [CHAR] m JV-LETTER IF DROP -1 JV-MAN ! JV-DRAW EXIT THEN
  [CHAR] j JV-LETTER IF DROP 0 JV-MAN ! JV-DRAW EXIT THEN
  [CHAR] r JV-LETTER IF DROP 0 JV-HOLD ! -1 JV-SHOW ! JV-SLIDE JV-DRAW EXIT THEN
  [CHAR] v JV-LETTER IF DROP JV-VIEW JV-DRAW EXIT THEN
  [CHAR] x JV-LETTER IF DROP
    JV-CF @ JV-CT @ JV-CF ! JV-CT !
    JV-DRAW EXIT
  THEN
  [CHAR] c JV-LETTER IF DROP
    JV-MAN @ IF
      -1 JV-TIG !
    ELSE
      JV-CF @ JV-CT @ JV-CF ! JV-CT !
    THEN
    JV-DRAW EXIT
  THEN
  JV-MAN @ IF
    [CHAR] b JV-LETTER IF DROP 0 JV-TIG ! JV-DRAW EXIT THEN
    [CHAR] d JV-LETTER IF DROP
      JV-DIST @ JV-FACT + JV-DIST !
      JV-DRAW EXIT
    THEN
    [CHAR] e JV-LETTER IF DROP
      JV-DIST @ JV-FACT - JV-DIST !
      JV-DRAW EXIT
    THEN
    [CHAR] p JV-LETTER IF DROP 1 JV-PAT +! JV-DRAW EXIT THEN
    [CHAR] o JV-LETTER IF DROP
      JV-PAT @ 1- 1 MAX JV-PAT !
      JV-DRAW EXIT
    THEN
  THEN
  DUP [CHAR] 1 = IF DROP 0 ['] JV-STD JV-USE JV-DRAW EXIT THEN
  DUP [CHAR] 2 = IF DROP 1 ['] JV-ANTI JV-USE JV-DRAW EXIT THEN
  DUP [CHAR] 3 = IF DROP 2 ['] JV-EXT JV-USE JV-DRAW EXIT THEN
  DUP [CHAR] 4 = IF DROP 3 ['] JV-EXTA JV-USE JV-DRAW EXIT THEN
  DUP [CHAR] 5 = IF DROP 4 ['] JV-CAM JV-USE JV-DRAW EXIT THEN
  DUP [CHAR] 6 = IF DROP 5 ['] JV-TIGP JV-USE JV-DRAW EXIT THEN
  DUP [CHAR] 7 = IF DROP 6 ['] JV-SNAKE JV-USE JV-DRAW EXIT THEN
  DUP [CHAR] 8 = IF DROP 7 ['] JV-TENT JV-USE JV-DRAW EXIT THEN
  DROP ;

: JV-CREDIT ( -- )
  S" JULIAV444-CORE20  Julia and Mandelbrot on twenty tasks." JV-LINE
  S" Marcel Hendrix, 1994. Jos v.d. Ven. Public domain." JV-LINE
  S" Fixed point, 28 fraction bits. Ten processors draw the columns." JV-LINE
  S" 1-8 style   M mandelbrot   J julia   V saved views" JV-LINE
  S" Arrows slide the picture. Shift-arrows zoom. ? key list." JV-LINE
  S" Click zooms in at that point. Option-click zooms out." JV-LINE
  S" PgUp PgDn zoom factor. H home. X swap colors." JV-LINE
  S" Mandelbrot: B interior  C tiger  D E distort  P O pattern" JV-LINE
  S" R random slides. Space holds the finished frame." JV-LINE
  S" S saves this picture. Choose JPEG, PNG, or TIFF." JV-LINE
  S" The next slide waits 2 seconds. Q or Esc quits." JV-LINE ;

\ n is the depth to keep. It sits above those cells, so a bare
\ DEPTH counts it too and would drop the caller's cell.
: JV-DRAIN ( n -- )
  >R
  BEGIN DEPTH R@ > WHILE DROP REPEAT
  R> DROP ;

\ Twenty tasks, ten processors. Tasks 0 through 9 start at
\ once and wait on JV-GATE. Task 0 then stops. Tasks 1 through 9
\ keep spinning on their processors until the ten waiting tasks
\ have run. They do not PAUSE. A pause would let a second task
\ already queued on that processor run, and a fixed share would
\ pass this test. Holding the processor means only a processor
\ that has stopped can take a waiting task. Task 0's processor
\ runs each waiting task in turn. A fixed share times out.
CREATE JV-SAW 20 CELLS ALLOT
CREATE JV-LATE 20 CELLS ALLOT
VARIABLE JV-GATE

: JV-MARK ( n -- )
  CELLS JV-SAW + -1 SWAP ! ;

: JV-SPIN ( -- )
  BEGIN JV-GATE @ UNTIL ;

\ n is the task number. The limit is the timeout.
\ Spin. PAUSE would give this processor to a task queued behind it.
: JV-LONG ( n -- )
  MS@ 3000 +
  BEGIN
    DUP MS@ < IF
      DROP
      CELLS JV-LATE + -1 SWAP !
      EXIT
    THEN
    0
    JV-NTASK JV-NCPU DO
      JV-SAW I CELLS + @ IF 1+ THEN
    LOOP
    JV-NCPU >= IF DROP DROP EXIT THEN
  AGAIN ;

: JV-JOB ( n -- )
  DUP JV-NCPU 1- > IF
    JV-SPIN
    JV-MARK
    STOP
  THEN
  DUP 0= IF
    JV-SPIN
    JV-MARK
    STOP
  THEN
  JV-SPIN
  DUP JV-MARK
  JV-LONG
  STOP ;

: JV-JOB00 ( -- ) JV-T00 ACTIVATE 0 JV-JOB ;
: JV-JOB01 ( -- ) JV-T01 ACTIVATE 1 JV-JOB ;
: JV-JOB02 ( -- ) JV-T02 ACTIVATE 2 JV-JOB ;
: JV-JOB03 ( -- ) JV-T03 ACTIVATE 3 JV-JOB ;
: JV-JOB04 ( -- ) JV-T04 ACTIVATE 4 JV-JOB ;
: JV-JOB05 ( -- ) JV-T05 ACTIVATE 5 JV-JOB ;
: JV-JOB06 ( -- ) JV-T06 ACTIVATE 6 JV-JOB ;
: JV-JOB07 ( -- ) JV-T07 ACTIVATE 7 JV-JOB ;
: JV-JOB08 ( -- ) JV-T08 ACTIVATE 8 JV-JOB ;
: JV-JOB09 ( -- ) JV-T09 ACTIVATE 9 JV-JOB ;
: JV-JOB10 ( -- ) JV-T10 ACTIVATE 10 JV-JOB ;
: JV-JOB11 ( -- ) JV-T11 ACTIVATE 11 JV-JOB ;
: JV-JOB12 ( -- ) JV-T12 ACTIVATE 12 JV-JOB ;
: JV-JOB13 ( -- ) JV-T13 ACTIVATE 13 JV-JOB ;
: JV-JOB14 ( -- ) JV-T14 ACTIVATE 14 JV-JOB ;
: JV-JOB15 ( -- ) JV-T15 ACTIVATE 15 JV-JOB ;
: JV-JOB16 ( -- ) JV-T16 ACTIVATE 16 JV-JOB ;
: JV-JOB17 ( -- ) JV-T17 ACTIVATE 17 JV-JOB ;
: JV-JOB18 ( -- ) JV-T18 ACTIVATE 18 JV-JOB ;
: JV-JOB19 ( -- ) JV-T19 ACTIVATE 19 JV-JOB ;

: JV-SPLIT-BAD ( -- flag )
  JV-SPLIT
  JV-LO @ 0<>
  JV-HI 19 CELLS + @ G-PX <> OR
  0 19 0 DO
    JV-HI I CELLS + @
    JV-LO I 1+ CELLS + @
    <> OR
  LOOP OR
  0 JV-NTASK 0 DO
    JV-LO I CELLS + @
    JV-HI I CELLS + @
    > OR
  LOOP OR ;

: JV-CORE-BAD ( -- flag )
  JV-SAW 20 CELLS 0 FILL
  JV-LATE 20 CELLS 0 FILL
  0 JV-GATE !
  SINGLE
  CORES
  JV-JOB00 JV-JOB01 JV-JOB02 JV-JOB03
  JV-JOB04 JV-JOB05 JV-JOB06 JV-JOB07
  JV-JOB08 JV-JOB09 JV-JOB10 JV-JOB11
  JV-JOB12 JV-JOB13 JV-JOB14 JV-JOB15
  JV-JOB16 JV-JOB17 JV-JOB18 JV-JOB19
  -1 JV-GATE !
  CORES-JOIN
  COOP
  SINGLE
  0
  JV-NTASK 0 DO
    JV-SAW I CELLS + @ 0= OR
  LOOP
  JV-NTASK 0 DO
    JV-LATE I CELLS + @ OR
  LOOP ;

: JV-SELFTEST ( -- )
  0 JV-BAD !
  DEPTH >R
  JV-RESET
  90 JV-ISIN 100000 <> IF
    -1 JV-BAD !
    S" juliav444-core20-fail sin" JV-LINE
  THEN
  JV-BAD @ 0= IF
    0 JV-CA ! 0 JV-CB !
    JV-M-ITER 0<> IF
      -1 JV-BAD !
      S" juliav444-core20-fail inside" JV-LINE
    THEN
  THEN
  JV-BAD @ 0= IF
    2.0e0 F>X JV-CA !
    0 JV-CB !
    JV-M-ITER
    1 80431637 * JV-CF @ + JV-PICK <> IF
      -1 JV-BAD !
      S" juliav444-core20-fail outside" JV-LINE
    THEN
  THEN
  JV-BAD @ 0= IF
    JV-MAP
    0 0 JV-JPIX
    JV-M-SETUP
    0 0 JV-MPIX
    JV-POLL DROP
  THEN
  JV-BAD @ 0= IF
    -20 4 JV-LIM -16 <> SWAP -24 <> OR IF
      -1 JV-BAD !
      S" juliav444-core20-fail lim" JV-LINE
    THEN
  THEN
  JV-BAD @ 0= IF
    JV-MINX @ JV-MAXX @ JV-MINY @ JV-MAXY @
    10 20 3 4 JV-BOX
    JV-MINX @ 7 <> JV-MAXX @ 13 <> OR
    JV-MINY @ 16 <> OR JV-MAXY @ 24 <> OR IF
      -1 JV-BAD !
      S" juliav444-core20-fail box" JV-LINE
    THEN
    JV-MAXY ! JV-MINY ! JV-MAXX ! JV-MINX !
  THEN
  JV-BAD @ 0= IF
    0 JV-XX ! 0 JV-YY !
    JV-STD DROP
    JV-ANTI DROP
    JV-EXT DROP
    JV-EXTA DROP
    JV-CAM DROP
    JV-TIGP DROP
    JV-SNAKE DROP
    JV-TENT DROP
  THEN
  JV-BAD @ 0= IF
    JV-SPLIT-BAD IF
      -1 JV-BAD !
      S" juliav444-core20-fail split" JV-LINE
    THEN
  THEN
  JV-BAD @ 0= IF
    JV-CORE-BAD IF
      -1 JV-BAD !
      S" juliav444-core20-fail cores" JV-LINE
    THEN
  THEN
  DEPTH R@ <> IF
    -1 JV-BAD !
    S" juliav444-core20-fail depth" JV-LINE
  THEN
  R> JV-DRAIN
  JV-BAD @ 0= IF S" juliav444-core20-ok" JV-LINE THEN ;

: JULIAV444-CORE20 ( -- )
  JV-SEED
  JV-RESET
  JV-CREDIT
  S" JULIAV444-CORE20" APP-NAME
  144 48 WINDOW-SIZE
  \ L! writes G-PIX directly. PREFRESH blits that map only after
  \ PIXEL-ON. PLOT turns pixel mode on; this draw path does not.
  PIXEL-ON
  TRUECOLOR
  SINGLE
  CORES
  JV-DRAW
  BEGIN
    JV-QUIT @ 0=
  WHILE
    JV-PEND @ ?DUP IF
      0 JV-PEND !
      JV-CMD
    ELSE JV-HIT @ IF
      0 JV-HIT !
      JV-CLICK
    ELSE JV-RESIZE @ IF
      JV-DRAW
    ELSE KEY? IF
      KEY JV-CMD
    ELSE JV-SHOW @ IF
      JV-SLIDE
      JV-DRAW
    ELSE JV-MDOWN IF
      JV-CLICK
    ELSE
      PAUSE
    THEN THEN THEN THEN THEN THEN
  REPEAT
  COOP
  SINGLE
  WINDOW-OFF ;

ONLY FORTH DEFINITIONS
DECIMAL

CR .( JULIAV444-CORE20 draws each frame as twenty tasks. )
CR .( Ten processors. A finished one takes the next task. )
CR .( Run:  JULIAV444-CORE20 ) CR
