\ 1TASKCLOCK.fth — cooperative task smoke (phase 1).
\ One counter task. MULTI lets it run on each console PAUSE.
\ SINGLE freezes it. STOP takes it out of the rotation.
\ GROWMEMORYMB from a background task is refused.
\ ANEW unlinks the tasks.
\ Run: EditForth --agent --no-autoload -f this file

\ Survives the ANEW below. ." is compiled; .( would print at compile time.
\ ALLOT overwrites the reclaimed task blocks. A leftover link faults on PAUSE.
: CHECK-GONE
  S" CLOCK" FORTH-WORDLIST SEARCH-WORDLIST
  IF DROP ." clock-still-defined" ELSE ." clock-gone" THEN CR
  S" GMM" FORTH-WORDLIST SEARCH-WORDLIST
  IF DROP ." gmm-still-defined" ELSE ." gmm-gone" THEN CR
  16384 ALLOT
  MULTI
  3 0 DO PAUSE LOOP
  ." anew-ok" CR ;

ANEW TASKCLOCK-MODULE

: NPAUSE ( n -- ) 0 DO PAUSE LOOP ;

PAUSE
.( pause-ok) CR
STOP
.( stop-console-ok) CR

VARIABLE TICKS
VARIABLE RUN
: BUMP BEGIN RUN @ 0= IF STOP THEN 1 TICKS +! PAUSE AGAIN ;
TASK: CLOCK
: START-CLOCK CLOCK ACTIVATE BUMP ;

DECIMAL
0 TICKS !  1 RUN !  START-CLOCK  MULTI
20 NPAUSE  .( ticks1=) TICKS @ . CR
SINGLE
5 NPAUSE   .( ticks2=) TICKS @ . CR
MULTI
0 RUN !
5 NPAUSE   .( ticks3=) TICKS @ . CR
1 RUN !  CLOCK WAKE
5 NPAUSE   .( ticks4=) TICKS @ . CR
CLOCK SLEEP

TASK: GMM
: GMM-BODY GMM ACTIVATE GROWMEMORYMB ;
GMM-BODY
PAUSE
.( gmm-returned) CR

ANEW TASKCLOCK-MODULE
CHECK-GONE
.( depth=) DEPTH . CR
