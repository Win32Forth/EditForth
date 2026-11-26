\ BALL.fth — a program loaded after SOWM and linked into a window.
\
\ The step moves a disk. The draw fills it. Both use the window output
\ words: SOWM-P@, SOWM-P!, SOWM-VIEW, and SOWM-PLOT. Local (0,0) is the
\ bottom-left of the content box.
\
\ Load:
\   S" /Users/thomaszimmer/Documents/EditForth/SOWM/SOWM-EF.fth" INCLUDED
\   S" /Users/thomaszimmer/Documents/EditForth/SOWM/BALL.fth" INCLUDED
\   SOWM
\
\ Starting SOWM opens one window of each linked program. Command-G
\ opens the next one. The ball is first when this file is loaded first.
\ The ball does not take keystrokes, and it leaves its text empty.
\ BALL-TEST checks the motion without opening the graphics window.
\
\ Public domain.

ONLY FORTH DEFINITIONS
DECIMAL
[DEFINED] ANEW [IF] ANEW BALL_MODULE [THEN]

: BALL-OK ( -- )
  ." ball-ok " CR
;

ONLY FORTH DEFINITIONS ALSO GRAPHICS

VARIABLE BD-X
VARIABLE BD-Y
VARIABLE BD-R

\ Slots 0..3 are x, y, dx, dy of the ball's square. Slot 4 is started.
: BALL-STEP ( -- )
  SOWM-OUT @ SOWM-LIVE? 0= IF EXIT THEN
  4 SOWM-P@ 0= IF
    4 0 SOWM-P!
    4 1 SOWM-P!
    3 2 SOWM-P!
    2 3 SOWM-P!
    -1 4 SOWM-P!
  THEN
  SOWM-OUT @ SOWM-VIEW >R >R 2DROP R> R>
  SOWM-BDIA - 0 MAX >R
  SOWM-BDIA - 0 MAX
  0 SOWM-P@ 2 SOWM-P@ +
  2 SOWM-P@
  ROT SOWM-AXIS
  2 SOWM-P!
  0 SOWM-P!
  R>
  1 SOWM-P@ 3 SOWM-P@ +
  3 SOWM-P@
  ROT SOWM-AXIS
  3 SOWM-P!
  1 SOWM-P!
;

\ Filled disk of diameter SOWM-BDIA. The origin is the bottom-left slot.
: BALL-DISK ( -- )
  0 SOWM-P@ BD-X !
  1 SOWM-P@ BD-Y !
  SOWM-BDIA 2/ BD-R !
  SOWM-BDIA 0 DO
    SOWM-BDIA 0 DO
      I BD-R @ - DUP *
      J BD-R @ - DUP *
      +
      BD-R @ DUP * <= IF
        BD-X @ I + BD-Y @ J + SOWM-PLOT
      THEN
    LOOP
  LOOP
;

: BALL-DRAW ( -- )
  $6CB6FF SOWM-INK !
  BALL-DISK
;

['] BALL-STEP ['] BALL-DRAW 0 SOWM-LINK

\ Headless motion check. Prints ball-ok.
\ Other programs may already be linked. Park that list, keep only the
\ ball for these checks, then put the list back before BALL-OK.
: BALL-TEST ( -- )
  SOWM-HOLD
  0 0 0 SOWM-LINK
  SOWM-RESET
  800 600 SOWM-SCREEN
  ['] BALL-STEP ['] BALL-DRAW 0 SOWM-LINK
  SOWM-NEW DROP
  SOWM-ATTACH 2 T=
  2 F-KEYS F@ 0 T=
  2 F-LEN F@ 0 T=
  2 F-DRAW F@ ['] BALL-DRAW T=
  2 F-STEP F@ ['] BALL-STEP T=
  2 SOWM-OUT !
  0 SOWM-P@ 0 T=
  4 SOWM-P@ 0 T=
  SOWM-TICK
  0 SOWM-P@ 7 T=
  1 SOWM-P@ 6 T=
  2 SOWM-P@ 3 T=
  3 SOWM-P@ 2 T=
  4 SOWM-P@ -1 T=
  2 F-LEN F@ 0 T=
  SOWM-TICK
  0 SOWM-P@ 10 T=
  1 SOWM-P@ 8 T=
  159 0 SOWM-P!
  3 2 SOWM-P!
  SOWM-TICK
  0 SOWM-P@ 162 T=
  2 SOWM-P@ 3 T=
  160 0 SOWM-P!
  3 2 SOWM-P!
  SOWM-TICK
  0 SOWM-P@ 162 T=
  2 SOWM-P@ -3 T=
  1 0 SOWM-P!
  -3 2 SOWM-P!
  SOWM-TICK
  0 SOWM-P@ 0 T=
  2 SOWM-P@ 3 T=
  48 32 2 SOWM-WH!
  2 SOWM-VIEW
  8 T= 42 T= 71 T= 71 T=
  100 0 SOWM-P!
  3 2 SOWM-P!
  50 1 SOWM-P!
  2 3 SOWM-P!
  SOWM-TICK
  0 SOWM-P@ 30 T=
  2 SOWM-P@ -3 T=
  1 SOWM-P@ 0 T=
  3 SOWM-P@ 0 T=
  SOWM-TICK
  0 SOWM-P@ 27 T=
  2 SOWM-P@ -3 T=
  1 SOWM-P@ 0 T=
  3 SOWM-P@ 0 T=
  180 110 2 SOWM-WH!
  2 SOWM-GO
  SOWM-DESK@ 2 T=
  2 F-DESK F@ 1 T=
  2 SOWM-OUT !
  10 0 SOWM-P!
  3 2 SOWM-P!
  10 1 SOWM-P!
  2 3 SOWM-P!
  SOWM-TICK
  SOWM-DESK@ 2 T=
  2 F-DESK F@ 1 T=
  0 SOWM-P@ 13 T=
  1 SOWM-P@ 12 T=
  2 SOWM-P@ 3 T=
  3 SOWM-P@ 2 T=
  SOWM-RESET
  800 600 SOWM-SCREEN
  SOWM-LSTEP @ ['] BALL-STEP T=
  SOWM-NEW DROP
  [CHAR] g 512 OR EF-KEY
  SOWM-COUNT 2 T=
  SOWM-FOCUS@ F-KEYS F@ 0 T=
  SOWM-FOCUS@ F-STEP F@ ['] BALL-STEP T=
  SOWM-FOCUS@ F-DRAW F@ ['] BALL-DRAW T=
  SOWM-FOCUS@ F-LEN F@ 0 T=
  DEPTH 0 T=
  SOWM-HELD
  BALL-OK
;

PREVIOUS
CR .( ball linked — Command-G opens the next program.) CR
