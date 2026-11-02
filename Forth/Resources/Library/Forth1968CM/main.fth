\ Charles Moore's 1968 IBM 1130 Forth, running in EditForth.
\ Open this folder and Include main.fth. Keyboard input is KEY.

S" Assembler.fth" INCLUDED
S" Machine.fth" INCLUDED
ALSO SYSVOC

DOC" LBUF ( -- addr ) 65536-byte buffer holding the joined assembler listing"
65536 ALLOCATE THROW CONSTANT LBUF

DOC" LLEN ( -- a-addr ) bytes currently stored in LBUF"
VARIABLE LLEN

DOC" ADD-PAGE ( a u -- ) read file a u, append it to LBUF, FREE the file address"
\ (SLURP) leaves ( addr u ). u is a full cell, not a count byte.
\ LLEN +! consumes u. FREE then receives addr. A newline is added
\ only when the file does not already end in linefeed.
: ADD-PAGE ( a u -- )
    (SLURP)
    DUP 0= IF 2DROP EXIT THEN
    2DUP LBUF LLEN @ + SWAP MOVE
    2DUP + 1- C@ 10 <> IF
        LBUF LLEN @ + OVER + 10 SWAP C!
        1+
    THEN
    LLEN +!
    FREE THROW ;

DOC" LOAD-LISTING ( -- ) clear LBUF and append listing pages 01 and 06 through 16"
: LOAD-LISTING ( -- )
    0 LLEN !
    S" Library/Forth1968CM/Resources/listing/asm-page-01.txt" ADD-PAGE
    S" Library/Forth1968CM/Resources/listing/asm-page-06.txt" ADD-PAGE
    S" Library/Forth1968CM/Resources/listing/asm-page-07.txt" ADD-PAGE
    S" Library/Forth1968CM/Resources/listing/asm-page-08.txt" ADD-PAGE
    S" Library/Forth1968CM/Resources/listing/asm-page-09.txt" ADD-PAGE
    S" Library/Forth1968CM/Resources/listing/asm-page-10.txt" ADD-PAGE
    S" Library/Forth1968CM/Resources/listing/asm-page-11.txt" ADD-PAGE
    S" Library/Forth1968CM/Resources/listing/asm-page-12.txt" ADD-PAGE
    S" Library/Forth1968CM/Resources/listing/asm-page-13.txt" ADD-PAGE
    S" Library/Forth1968CM/Resources/listing/asm-page-14.txt" ADD-PAGE
    S" Library/Forth1968CM/Resources/listing/asm-page-15.txt" ADD-PAGE
    S" Library/Forth1968CM/Resources/listing/asm-page-16.txt" ADD-PAGE ;

DOC" FORTH-1968 ( -- ) assemble FORTH.asm, check the listing, boot FO.FO, run"
\ COMPARE-LISTING reads LBUF. M-RUN stops on halt or a stuck loop.
\ M-HI is set when the console prints HI THERE.
: FORTH-1968 ( -- )
    S" Library/Forth1968CM/Resources/FORTH.asm" (SLURP)
    DUP 0= IF 2DROP ." empty FORTH.asm" CR 1 THROW THEN
    2DUP ASSEMBLE   \ Assemble FORTH.asm
    DROP FREE THROW
    A-NERR @ IF A-.ERRS 1 THROW THEN
    LOAD-LISTING    \ load the listing files for comparison
                    \ Compare the listing with the code that was assembled
    LBUF LLEN @ COMPARE-LISTING >R
    LBUF FREE THROW
    R> ?DUP IF 1 THROW THEN
    ." Assembled FORTH.asm: " A-LO @ .H4 ." –" A-HI @ .H4
    ." , entry " A-ENTRY @ .H4 ." , listing matches." CR

    S" Library/Forth1968CM/Resources/FO.FO" (SLURP)
    DUP 0= IF 2DROP ." empty FO.FO" CR 1 THROW THEN
    2DUP M-BOOT
    DROP FREE THROW
    ." First disk record: " M-FIRST
    200000000 M-RUN     \ Run Forth-1968, it should display HI THERE
    M-WHY. CR
    M-HI @ 0= IF
        ." Did not print HI THERE" CR
        M-TRACE
        1 THROW
    THEN ;

.( Type FORTH-1968 <return> to compile, build and run FORTH-1968 ) CR

\S

Here is an example of a simple interaction with Forth-1968.
ok(0)> FORTH-1968
Assembled FORTH.asm: 0900–0DC3, entry 09FA, listing matches.
First disk record: .DEP LOC DEPOSIT, .DEPOSIT IC INC=,
HI THERE
23 34 + 10 / swap 100 * + alpha 1 + = 2 alpha = reply
23 34 + 10 / SWAP 100 * + ALPHA 1 + = 2 ALPHA = REPLY
57

