\ TASKSEM.fth — binary semaphore smoke (step 3).
\ 1 is free, 0 is taken. CLAIM stores 0 only while the reservation holds.
\ SIGNAL stores 1 and yields. WAIT claims, and yields while the cell is 0.
\ A second WAIT does not see a signal that was already claimed.
\ Run: EditForth --agent --no-autoload -f this file

ANEW TASKSEM-MODULE

VARIABLE FLAG
VARIABLE HITS
VARIABLE EMPTY

: NPAUSE ( n -- ) 0 DO PAUSE LOOP ;

FLAG RELEASE
FLAG CLAIM . CR
FLAG CLAIM . CR
FLAG RELEASE
FLAG CLAIM . CR
FLAG RELEASE

GRAPHICS-SEM @ . CR
GRAPHICS-SEM CLAIM DROP
GRAPHICS-SEM @ . CR
GRAPHICS-SEM RELEASE
CONSOLE-SEM @ . CR
DICT-SEM CLAIM DROP
DICT-SEM RELEASE
DICT-SEM @ . CR

EMPTY WAIT
.( wait-stuck-ok) CR

: PROD-BODY BEGIN FLAG SIGNAL STOP AGAIN ;
: CONS-BODY BEGIN FLAG WAIT 1 HITS +! STOP AGAIN ;
\ PROD is created second so it is the newest task and runs first.
TASK: CONS
TASK: PROD
: START-PROD PROD ACTIVATE PROD-BODY ;
: START-CONS CONS ACTIVATE CONS-BODY ;

DECIMAL
0 HITS !
0 FLAG !
START-CONS
START-PROD
MULTI
1 NPAUSE .( hits1=) HITS @ . CR
1 NPAUSE .( hits2=) HITS @ . CR
PROD WAKE
CONS WAKE
1 NPAUSE .( hits3=) HITS @ . CR
1 NPAUSE .( hits4=) HITS @ . CR
CONS WAKE
1 NPAUSE .( hits5=) HITS @ . CR
PROD WAKE
1 NPAUSE .( hits6=) HITS @ . CR
SINGLE
.( sem-ok) CR
.( depth=) DEPTH . CR
