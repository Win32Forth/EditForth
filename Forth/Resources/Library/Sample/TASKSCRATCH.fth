\ TASKSCRATCH.fth — per-task WORD, PAD, and pictured output.
\ Two tasks each parse a different name and convert a different number.
\ A PAUSE sits between WORD and the copy, and inside <# ... #>,
\ so a shared buffer would show the other task's text.
\ Run: EditForth --agent --no-autoload -f this file

ANEW TASKSCRATCH-MODULE

DECIMAL

CREATE A-NAME 64 ALLOT
CREATE B-NAME 64 ALLOT
CREATE A-PIC 32 ALLOT
CREATE B-PIC 32 ALLOT
VARIABLE A-PL
VARIABLE B-PL

\ counted string at c-addr, including the length byte, into dest
: KEEP-WORD ( c-addr dest -- ) OVER C@ 1+ MOVE ;

: A-GO
    S" alpha-one junk" (SOURCE!)
    BL WORD
    PAUSE
    A-NAME KEEP-WORD
    <# PAUSE 111 0 #S PAUSE #> A-PIC SWAP DUP A-PL ! MOVE
    STOP ;

: B-GO
    S" beta-two junk" (SOURCE!)
    BL WORD
    PAUSE
    B-NAME KEEP-WORD
    <# PAUSE 222 0 #S PAUSE #> B-PIC SWAP DUP B-PL ! MOVE
    STOP ;

TASK: TASK-A
TASK: TASK-B
: START-A TASK-A ACTIVATE A-GO ;
: START-B TASK-B ACTIVATE B-GO ;

: NPAUSE ( n -- ) 0 DO PAUSE LOOP ;

MULTI
START-A
START-B
8 NPAUSE

: SHOW
    ." A-word=" A-NAME COUNT TYPE CR
    ." B-word=" B-NAME COUNT TYPE CR
    ." A-pic=" A-PIC A-PL @ TYPE CR
    ." B-pic=" B-PIC B-PL @ TYPE CR
    A-NAME COUNT S" alpha-one" COMPARE 0=
    B-NAME COUNT S" beta-two" COMPARE 0= AND
    A-PIC A-PL @ S" 111" COMPARE 0= AND
    B-PIC B-PL @ S" 222" COMPARE 0= AND
    IF ." scratch-ok" ELSE ." scratch-bad" THEN CR ;
SHOW

\ A background INCLUDE or LOAD stops that task. The console line continues.
: BAD-INC S" nosuch-taskscratch.fth" INCLUDED ;
: BAD-LOAD 1 LOAD ;
TASK: TASK-I
TASK: TASK-L
: START-I TASK-I ACTIVATE BAD-INC ;
: START-L TASK-L ACTIVATE BAD-LOAD ;
START-I
START-L
4 NPAUSE
." refuse-returned" CR
SINGLE
." single-ok" CR
." depth=" DEPTH . CR
