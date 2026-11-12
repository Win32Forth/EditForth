\ TASKQUEUE.fth — mailbox and fixed-ring smoke (step 4).
\ A mailbox is a value plus a full/empty pair, allotted once.
\ A ring is one producer and one consumer. Head == tail means empty.
\ The producer publishes the tail with a release store. The consumer
\ acquire-loads that tail. Depth stays below the slot count.
\ Run: EditForth --agent --no-autoload -f this file

ANEW TASKQUEUE-MODULE

: NPAUSE ( n -- ) 0 DO PAUSE LOOP ;

DECIMAL
MAILBOX CONSTANT BOX
2 QUEUE CONSTANT TINY

0 BOX >MBOX
1 BOX >MBOX
.( mbox-stuck-ok) CR
BOX MBOX> .
.( mbox-held) CR

0 TINY >Q
1 TINY >Q
.( q-stuck-ok) CR
TINY Q> .
TINY Q-DEPTH .
.( tiny-ok) CR

VARIABLE MGOT
VARIABLE MBAD
VARIABLE QGOT
VARIABLE QBAD
VARIABLE HI

: MPROD-BODY ( -- )
  8 0 DO I BOX >MBOX LOOP
  STOP ;
: MCONS-BODY ( -- )
  8 0 DO
    BOX MBOX>
    MGOT @ <> IF 1 MBAD +! THEN
    1 MGOT +!
  LOOP
  STOP ;

\ The consumer is created first. The producer is newest and runs first.
TASK: MCONS
TASK: MPROD
: START-MPROD ( -- ) MPROD ACTIVATE MPROD-BODY ;
: START-MCONS ( -- ) MCONS ACTIVATE MCONS-BODY ;

0 MGOT !
0 MBAD !
START-MCONS
START-MPROD
MULTI
12 NPAUSE
SINGLE
MCONS SLEEP
MPROD SLEEP

16 QUEUE CONSTANT RING

: QPROD-BODY ( -- )
  4096 0 DO I RING >Q LOOP
  STOP ;
: QCONS-BODY ( -- )
  4096 0 DO
    RING Q-DEPTH HI @ MAX HI !
    RING Q>
    QGOT @ <> IF 1 QBAD +! THEN
    1 QGOT +!
  LOOP
  STOP ;

TASK: QCONS
TASK: QPROD
: START-QPROD ( -- ) QPROD ACTIVATE QPROD-BODY ;
: START-QCONS ( -- ) QCONS ACTIVATE QCONS-BODY ;

0 QGOT !
0 QBAD !
0 HI !
START-QCONS
START-QPROD
MULTI
300 NPAUSE
SINGLE
QCONS SLEEP
QPROD SLEEP

: REPORT ( -- )
  ." mbox-got=" MGOT @ . ." mbox-bad=" MBAD @ . CR
  ." q-got=" QGOT @ . ." q-bad=" QBAD @ . CR
  ." q-hi=" HI @ . ." q-depth=" RING Q-DEPTH . CR
  MGOT @ 8 = MBAD @ 0= AND
  IF ." mbox-ok" ELSE ." mbox-fail" THEN CR
  QGOT @ 4096 = QBAD @ 0= AND
  HI @ 0> AND HI @ 16 < AND
  RING Q-DEPTH 0= AND
  IF ." queue-ok" ELSE ." queue-fail" THEN CR
  ." depth=" DEPTH . CR ;

REPORT
