\ 6TASKSLICE.fth — private dictionary slice (phase 6).
\ One cooperative task compiles and allots into SLICE.
\ Console HERE stays where it was. WORD writes scratch, not that HERE.
\ A task with no slice cannot ALLOT. A CORES worker still cannot EVALUATE.
\ IF / ELSE / THEN are compile-only, so the reports are colon words.
\ REPORT-GONE is defined before the marker so the later ANEW keeps it.
\ Run: EditForth --agent --no-autoload -f this file

DECIMAL
: REPORT-GONE ( -- )
  S" ANSWER" FORTH-WORDLIST SEARCH-WORDLIST
  IF DROP ." answer-still" ELSE ." answer-gone" THEN CR
  S" COMP" FORTH-WORDLIST SEARCH-WORDLIST
  IF DROP ." comp-still" ELSE ." comp-gone" THEN CR
  ." depth=" DEPTH . CR ;

ANEW TASKSLICE-MODULE
DECIMAL

VARIABLE FENCE
VARIABLE DONE
VARIABLE BARE-HIT
VARIABLE WENT
VARIABLE WH
VARIABLE WH2
VARIABLE WB

TASK: COMP
4096 COMP SLICE
TASK: BARE

: COMP-BODY
  COMP ACTIVATE
  S" : ANSWER 42 ; CREATE BUF 16 ALLOT 99 BUF ! HERE WH ! BL WORD ZED WB ! HERE WH2 !"
  EVALUATE
  1 DONE !
  STOP ;

: BARE-BODY
  BARE ACTIVATE
  8 ALLOT
  1 BARE-HIT !
  STOP ;

: START-COMP ( -- ) COMP-BODY ;
: START-BARE ( -- ) BARE-BODY ;
: WAIT-COMP ( -- ) BEGIN DONE @ 0= WHILE PAUSE REPEAT ;
: REPORT-SLICE ( -- )
  HERE FENCE @ = IF ." fence-held" ELSE ." fence-moved" THEN CR
  WH @ FENCE @ < IF ." slice-below" ELSE ." slice-not-below" THEN CR
  COMP WH @ < IF ." here-after-task" ELSE ." here-inside-task" THEN CR
  WH @ WH2 @ = IF ." word-stable" ELSE ." word-moved" THEN CR
  WB @ WH @ < IF ." word-apart" ELSE ." word-at-here" THEN CR
  ." bare-hit=" BARE-HIT @ . CR ;

HERE FENCE !
0 DONE !
0 BARE-HIT !
0 WENT !
MULTI
START-COMP
START-BARE
WAIT-COMP
SINGLE

REPORT-SLICE
ANSWER .( answer=) . CR
BUF @ .( buf=) . CR

CORES
TASK: W
: WBODY
  W ACTIVATE
  S" : NOPE 1 ;" EVALUATE
  1 WENT !
  STOP ;
: START-W ( -- ) WBODY ;
START-W
CORES-JOIN
COOP
WENT @ .( went=) . CR
.( depth=) DEPTH . CR

ANEW TASKSLICE-MODULE
REPORT-GONE
