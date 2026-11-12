\ TASKCORES.fth — two worker queues overlap through the step-4 ring.
\ Each task sets a live cell before the transfer and clears it at the end.
\ The console waits until both cells are set, prints, then waits for both
\ tasks to stop. The ring holds 15 cells, so 100000 sends must overlap.
\ BEGIN / UNTIL are compile-only, so the wait is a colon word.
\ Run: EditForth --agent --no-autoload -f this file

ANEW TASKCORES-MODULE

DECIMAL

VARIABLE PLIVE
VARIABLE CLIVE
VARIABLE OVERLAP
VARIABLE PGOT
VARIABLE CGOT
VARIABLE CBAD
VARIABLE SAW

16 QUEUE CONSTANT RING

: P-BODY ( -- )
  1 PLIVE !
  100000 0 DO
    I RING >Q
    1 PGOT +!
    CLIVE @ IF 1 OVERLAP ! THEN
  LOOP
  0 PLIVE !
  STOP ;

: C-BODY ( -- )
  1 CLIVE !
  100000 0 DO
    RING Q>
    DUP I <> IF 1 CBAD +! THEN
    DROP
    1 CGOT +!
    PLIVE @ IF 1 OVERLAP ! THEN
  LOOP
  0 CLIVE !
  STOP ;

TASK: PROD
TASK: CONS

: START-PROD ( -- ) PROD ACTIVATE P-BODY ;
: START-CONS ( -- ) CONS ACTIVATE C-BODY ;
: WAIT-LIVE ( -- ) BEGIN PLIVE @ CLIVE @ AND UNTIL ;

CORES
START-CONS
START-PROD
WAIT-LIVE
1 SAW !
.( console-ok ) PLIVE @ . CLIVE @ . SAW @ . CR
CORES-JOIN
COOP
.( overlap=) OVERLAP @ . CR
.( pgot=) PGOT @ . CR
.( cgot=) CGOT @ . CR
.( cbad=) CBAD @ . CR
.( q-depth=) RING Q-DEPTH . CR
.( depth=) DEPTH . CR
