\ IBM 1130 assembler for the card-column subset in FORTH.asm.
\ Two passes. A short B that does not fit is widened on the next attempt.
\ forceLong is kept across those attempts. LIBF occupies one memory word;
\ the printed object is the subroutine name code.

DECIMAL

400 CONSTANT A-MAXSYM
1600 CONSTANT A-MAXREC
48 CONSTANT A-MAXLIB
40 CONSTANT A-MAXERR
96 CONSTANT A-ERRW
32768 CONSTANT A-MEM

VARIABLE A-PASS
VARIABLE A-TRY
VARIABLE A-LC
VARIABLE A-ORG
VARIABLE A-ENTRY
VARIABLE A-LINK
VARIABLE A-ACCEPT
VARIABLE A-RETRY
VARIABLE A-LO
VARIABLE A-HI
VARIABLE A-NSYM
VARIABLE A-NREC
VARIABLE A-NLIB
VARIABLE A-NERR
VARIABLE A-LINE
VARIABLE A-SRC
VARIABLE A-SU
VARIABLE A-PA
VARIABLE A-PU
VARIABLE A-LN

CREATE A-LAB 8 ALLOT
VARIABLE A-LABN
CREATE A-MBUF 8 ALLOT
VARIABLE A-MNEMN
CREATE A-MODB 4 ALLOT
VARIABLE A-MODN
CREATE A-OPB 48 ALLOT
VARIABLE A-OPN
CREATE A-WDS 4 CELLS ALLOT

CREATE A-IMAGE A-MEM CELLS ALLOT
CREATE A-NAMES A-MAXSYM 8 * ALLOT
CREATE A-NLEN A-MAXSYM CELLS ALLOT
CREATE A-VALS A-MAXSYM CELLS ALLOT
CREATE A-RECS A-MAXREC 6 * CELLS ALLOT
CREATE A-LIBA A-MAXLIB CELLS ALLOT
CREATE A-LIBK A-MAXLIB CELLS ALLOT
CREATE A-ERR A-MAXERR A-ERRW * ALLOT
CREATE A-FORCE 800 CELLS ALLOT

VARIABLE XP-A
VARIABLE XP-U
VARIABLE XP-I
VARIABLE XP-STAR
VARIABLE XP-PASS
VARIABLE XP-BAD
VARIABLE XP-ANY
VARIABLE XP-VAL
CREATE XP-MSG 80 ALLOT
CREATE XP-SYM 32 ALLOT
VARIABLE XP-SN
CREATE A-SCR 160 ALLOT
VARIABLE A-SCRN

: STR= ( a u a2 u2 -- flag ) COMPARE 0= ;
: SCR0 ( -- ) 0 A-SCRN ! ;
: SCR+ ( a u -- )
    A-SCRN @ OVER + 150 > IF 2DROP EXIT THEN
    A-SCR A-SCRN @ + SWAP DUP >R MOVE R> A-SCRN +! ;
: SCR-C ( c -- )
    A-SCRN @ 150 < IF A-SCR A-SCRN @ + C! 1 A-SCRN +! ELSE DROP THEN ;
: SCR-N ( n -- )
    BASE @ >R DECIMAL
    DUP 0< IF NEGATE S" -" SCR+ THEN
    0 <# #S #> SCR+
    R> BASE ! ;
: >HD ( n -- c ) 15 AND DUP 10 < IF 48 ELSE 55 THEN + ;
: SCR-H4 ( n -- )
    DUP 12 RSHIFT >HD SCR-C
    DUP 8 RSHIFT >HD SCR-C
    DUP 4 RSHIFT >HD SCR-C
    >HD SCR-C ;
: .H4 ( n -- )
    DUP 12 RSHIFT >HD EMIT
    DUP 8 RSHIFT >HD EMIT
    DUP 4 RSHIFT >HD EMIT
    >HD EMIT ;

: A-ERR! ( a u -- )
    A-NERR @ A-MAXERR < IF
        A-ERRW 1- MIN
        A-NERR @ A-ERRW * A-ERR + PLACE
    ELSE
        2DROP
    THEN
    1 A-NERR +! ;
: ERR-L ( -- )
    SCR0 S" L" SCR+ A-LINE @ SCR-N S" : " SCR+ ;

: -LEADING ( a u -- a u )
    BEGIN DUP WHILE OVER C@ BL = WHILE 1 /STRING REPEAT THEN ;

: A-HAS ( c -- flag )
    \ The character stays on the data stack. DO hides a saved R@ value.
    A-MODN @ 0 ?DO
        DUP A-MODB I + C@ = IF DROP TRUE UNLOOP EXIT THEN
    LOOP
    DROP FALSE ;

: A-TAG ( -- n )
    [CHAR] 1 A-HAS IF 1 EXIT THEN
    [CHAR] 2 A-HAS IF 2 EXIT THEN
    [CHAR] 3 A-HAS IF 3 EXIT THEN
    0 ;

: A-BITS ( base forced -- op long )
    {: base forced | op long :}
    base TO op
    A-TAG
    DUP 1 = IF 256 op + TO op THEN
    DUP 2 = IF 512 op + TO op THEN
    3 = IF 768 op + TO op THEN
    forced [CHAR] L A-HAS OR [CHAR] I A-HAS OR TO long
    long IF
        op 1024 OR TO op
        [CHAR] I A-HAS IF op 128 OR TO op THEN
    THEN
    op long ;

: A-FIND ( a u -- n true | false )
    {: a u | hit val :}
    0 TO hit
    0 TO val
    A-NSYM @ 0 ?DO
        I CELLS A-NLEN + @ u = IF
            a u  A-NAMES I 8 * + u  STR= IF
                -1 TO hit
                I CELLS A-VALS + @ TO val
                LEAVE
            THEN
        THEN
    LOOP
    hit IF val TRUE ELSE FALSE THEN ;

: A-NEW ( a u n -- )
    A-NSYM @ A-MAXSYM >= IF DROP 2DROP EXIT THEN
    A-NSYM @ CELLS A-VALS + !
    DUP 8 MIN A-NSYM @ CELLS A-NLEN + !
    A-NSYM @ 8 * A-NAMES + 8 ERASE
    8 MIN A-NSYM @ 8 * A-NAMES + SWAP MOVE
    1 A-NSYM +! ;

: A-DEFINE ( -- )
    A-LABN @ 0= IF EXIT THEN
    A-PASS @ 1 = IF
        A-LAB A-LABN @ A-FIND IF
            DROP
            ERR-L S" duplicate label " SCR+
            A-LAB A-LABN @ SCR+
            A-SCR A-SCRN @ A-ERR!
        ELSE
            A-LAB A-LABN @ A-LC @ A-NEW
        THEN
    ELSE
        A-LAB A-LABN @ A-FIND IF
            A-LC @ <> IF
                ERR-L S" phase error " SCR+
                A-LAB A-LABN @ SCR+
                A-SCR A-SCRN @ A-ERR!
            THEN
        ELSE
            ERR-L S" phase error " SCR+
            A-LAB A-LABN @ SCR+
            A-SCR A-SCRN @ A-ERR!
        THEN
    THEN ;

: A-WRITE ( w addr -- )
    DUP A-LO @ < IF DUP A-LO ! THEN
    DUP A-HI @ > IF DUP A-HI ! THEN
    DUP 0 A-MEM WITHIN IF
        CELLS A-IMAGE + SWAP 65535 AND SWAP !
    ELSE
        2DROP
    THEN ;

: PACK4 ( a u -- n )
    0 SWAP 4 MIN 0 ?DO
        8 LSHIFT OVER I + C@ 255 AND OR
    LOOP NIP ;

: A-REC ( addr rel obj wid -- )
    A-NREC @ A-MAXREC >= IF 2DROP 2DROP EXIT THEN
    A-NREC @ 6 * CELLS A-RECS +
    \ Names follow the stack, deepest first. {: :} pops TOS into the last name.
    {: addr rel obj wid slot :}
    addr slot !
    rel slot CELL+ !
    obj slot 2 CELLS + !
    wid slot 3 CELLS + !
    A-MBUF A-MNEMN @ PACK4 slot 4 CELLS + !
    A-MNEMN @ slot 5 CELLS + !
    1 A-NREC +! ;

: A-EMIT ( words n adv rel obj wid -- )
    {: words n adv rel obj wid :}
    A-PASS @ 2 = IF
        A-LC @ rel obj wid A-REC
        n 0 ?DO
            words I CELLS + @  A-LC @ I + A-WRITE
        LOOP
    THEN
    adv A-LC +! ;

: A-ONE ( word rel obj -- )
    {: word rel obj :}
    word A-WDS !
    A-WDS 1 1 rel obj 4 A-EMIT ;

: A-TWO ( w1 w2 rel obj -- )
    {: w1 w2 rel obj :}
    w1 A-WDS !
    w2 A-WDS CELL+ !
    A-WDS 2 2 rel obj 8 A-EMIT ;

: A-FOUR ( w1 w2 w3 w4 rel obj -- )
    {: w1 w2 w3 w4 rel obj :}
    w1 A-WDS !
    w2 A-WDS CELL+ !
    w3 A-WDS 2 CELLS + !
    w4 A-WDS 3 CELLS + !
    A-WDS 4 4 rel obj 8 A-EMIT ;

: A-NONE ( adv rel obj wid -- )
    {: adv rel obj wid :}
    0 0 adv rel obj wid A-EMIT ;

: XP-CH ( -- c )
    XP-I @ XP-U @ >= IF 0 EXIT THEN
    XP-A @ XP-I @ + C@ ;
: XP-MSG! ( a u -- )
    XP-BAD @ IF 2DROP EXIT THEN
    79 MIN XP-MSG PLACE
    -1 XP-BAD ! ;

: DIGIT? ( c base -- n true | false )
    OVER 48 58 WITHIN IF
        >R 48 - R>
    ELSE OVER 65 91 WITHIN IF
        >R 55 - R>
    ELSE OVER 97 123 WITHIN IF
        >R 87 - R>
    ELSE
        2DROP FALSE EXIT
    THEN THEN THEN
    2DUP < IF DROP TRUE ELSE 2DROP FALSE THEN ;

: XP-NUM ( base -- n )
    0 XP-VAL ! 0 XP-ANY !
    BEGIN XP-CH OVER DIGIT? WHILE
        >R XP-VAL @ OVER * R> + XP-VAL !
        1 XP-I +!
        -1 XP-ANY !
    REPEAT
    DROP
    XP-ANY @ 0= IF S" missing number" XP-MSG! THEN
    XP-VAL @ ;

: SYM-C? ( c -- flag )
    DUP 65 91 WITHIN OVER 97 123 WITHIN OR
    OVER 48 58 WITHIN OR SWAP 36 = OR ;
: START-C? ( c -- flag )
    DUP SYM-C? OVER 35 = OR SWAP 64 = OR ;

: XP-SYM ( -- n )
    0 XP-SN !
    BEGIN XP-CH DUP SYM-C? WHILE
        XP-SN @ 31 < IF XP-SYM XP-SN @ + C! 1 XP-SN +! THEN
        1 XP-I +!
    REPEAT
    DROP
    XP-SYM XP-SN @ A-FIND IF EXIT THEN
    XP-PASS @ 2 = IF
        S" undefined " XP-MSG!
        XP-SYM XP-SN @ 79 XP-MSG C@ - 0 MAX MIN
        XP-MSG COUNT + SWAP MOVE
        XP-MSG C@ XP-SN @ + 79 MIN XP-MSG C!
    THEN
    0 ;

: XP-TERM ( -- n )
    XP-CH DUP 0= IF DROP S" missing term" XP-MSG! 0 EXIT THEN
    DUP 42 = IF DROP 1 XP-I +! XP-STAR @ EXIT THEN
    DUP 47 = IF DROP 1 XP-I +! 16 XP-NUM EXIT THEN
    DUP 48 58 WITHIN IF DROP 10 XP-NUM EXIT THEN
    DUP START-C? IF DROP XP-SYM EXIT THEN
    DROP S" bad term" XP-MSG! 1 XP-I +! 0 ;

: XP-UNARY ( -- n )
    XP-CH DUP 45 = IF DROP 1 XP-I +! RECURSE NEGATE EXIT THEN
    DUP 43 = IF DROP 1 XP-I +! RECURSE EXIT THEN
    DROP XP-TERM ;

: XP-PROD ( -- n )
    XP-UNARY
    BEGIN XP-CH DUP 42 = OVER 47 = OR OVER 38 = OR WHILE
        DUP 42 = IF DROP 1 XP-I +! XP-UNARY *
        ELSE DUP 47 = IF DROP 1 XP-I +! XP-UNARY DUP IF / ELSE 2DROP 0 THEN
        ELSE DROP 1 XP-I +! XP-UNARY AND
        THEN THEN
    REPEAT DROP ;

: XP-SUM ( -- n )
    XP-PROD
    BEGIN XP-CH DUP 43 = OVER 45 = OR WHILE
        45 = 1 XP-I +! >R XP-PROD R> IF - ELSE + THEN
    REPEAT DROP ;

: XP-PARSE ( a u star pass -- n )
    XP-PASS ! XP-STAR ! XP-U ! XP-A !
    0 XP-I ! 0 XP-BAD !
    XP-SUM
    XP-I @ XP-U @ < XP-BAD @ 0= AND IF S" trailing" XP-MSG! THEN
    XP-BAD @ IF
        ERR-L XP-MSG COUNT SCR+ S"  in " SCR+
        XP-A @ XP-U @ SCR+
        A-SCR A-SCRN @ A-ERR!
    THEN ;

: A-EVAL-TO ( a u -- n )
    DUP 0= IF 2DROP 0 EXIT THEN
    A-LC @ A-ORG @ + A-PASS @ XP-PARSE ;

: A-DISP ( value rel -- byte )
    IF A-LC @ 1+ - THEN
    A-PASS @ 1 = IF 255 AND EXIT THEN
    DUP -128 < OVER 127 > OR IF
        A-MBUF A-MNEMN @ S" B" STR=
        A-TRY @ 6 < AND
        A-LINE @ CELLS A-FORCE + @ 0= AND IF
            A-LINE @ CELLS A-FORCE + -1 SWAP !
            -1 A-RETRY !
            DROP 0 EXIT
        THEN
        ERR-L S" displacement " SCR+ DUP SCR-N
        S"  at " SCR+ A-LC @ SCR-H4
        A-SCR A-SCRN @ A-ERR!
        DROP 0 EXIT
    THEN
    255 AND ;

: A-REL? ( -- flag )
    A-MBUF A-MNEMN @ S" LDX" STR= IF FALSE EXIT THEN
    A-MBUF A-MNEMN @ S" STX" STR= IF TRUE EXIT THEN
    A-TAG 0= ;

: SPLIT-COMMA ( a u -- a1 u1 a2 u2 flag )
    {: a u | cut :}
    -1 TO cut
    u 0 ?DO a I + C@ 44 = IF I TO cut LEAVE THEN LOOP
    cut 0< IF a u 0 0 FALSE
    ELSE a cut  a cut 1+ +  u cut 1+ -  TRUE THEN ;

: EB6 ( c -- n )
    DUP 32 = IF DROP 0 EXIT THEN
    DUP 48 58 WITHIN IF EXIT THEN
    DUP 65 74 WITHIN IF 65 - 1+ EXIT THEN
    DUP 74 83 WITHIN IF 74 - 17 + EXIT THEN
    DUP 83 91 WITHIN IF 83 - 34 + EXIT THEN
    DROP 0 ;

: NAMECODE ( a u -- n )
    0 5 0 DO
        6 LSHIFT
        I 2 PICK < IF 2 PICK I + C@ ELSE 32 THEN EB6 OR
    LOOP NIP NIP ;

: CMASK ( a u -- n )
    {: a u | mask :}
    0 TO mask
    u 0 ?DO
        a I + C@
        DUP 90 = IF mask 32 OR TO mask THEN
        DUP 45 = IF mask 16 OR TO mask THEN
        DUP 43 = IF mask 8 OR TO mask THEN
        DUP 38 = IF mask 8 OR TO mask THEN
        DUP 69 = IF mask 4 OR TO mask THEN
        DUP 67 = IF mask 2 OR TO mask THEN
        79 = IF mask 1 OR TO mask THEN
    LOOP
    mask ;

: STD-OP ( a u -- base true | false )
    2DUP S" A" STR= IF 2DROP 32768 TRUE EXIT THEN
    2DUP S" AD" STR= IF 2DROP 34816 TRUE EXIT THEN
    2DUP S" S" STR= IF 2DROP 36864 TRUE EXIT THEN
    2DUP S" SD" STR= IF 2DROP 38912 TRUE EXIT THEN
    2DUP S" M" STR= IF 2DROP 40960 TRUE EXIT THEN
    2DUP S" D" STR= IF 2DROP 43008 TRUE EXIT THEN
    2DUP S" LD" STR= IF 2DROP 49152 TRUE EXIT THEN
    2DUP S" LDD" STR= IF 2DROP 51200 TRUE EXIT THEN
    2DUP S" STO" STR= IF 2DROP 53248 TRUE EXIT THEN
    2DUP S" STD" STR= IF 2DROP 55296 TRUE EXIT THEN
    2DUP S" AND" STR= IF 2DROP 57344 TRUE EXIT THEN
    2DUP S" OR" STR= IF 2DROP 59392 TRUE EXIT THEN
    2DUP S" EOR" STR= IF 2DROP 61440 TRUE EXIT THEN
    2DUP S" LDX" STR= IF 2DROP 24576 TRUE EXIT THEN
    2DUP S" STX" STR= IF 2DROP 26624 TRUE EXIT THEN
    2DUP S" XIO" STR= IF 2DROP 2048 TRUE EXIT THEN
    2DROP FALSE ;

: A-KIND ( a u -- kind )
    2DUP S" DISK1" STR= IF 2DROP 1 EXIT THEN
    2DUP S" PRNT1" STR= IF 2DROP 2 EXIT THEN
    2DROP 0 ;

: A-STD ( base -- )
    0 A-BITS
    {: op long | value obj :}
    long IF 2 ELSE 1 THEN A-ORG !
    A-DEFINE
    A-OPB A-OPN @ A-EVAL-TO TO value
    long IF
        op 65535 AND TO op
        value 65535 AND TO value
        op 16 LSHIFT value OR TO obj
        op value 2 obj A-TWO
    ELSE
        value A-REL? A-DISP op OR 65535 AND
        DUP 1 SWAP A-ONE
    THEN ;

: A-SHIFT ( base -- )
    1 A-ORG !
    A-DEFINE
    A-OPB A-OPN @ A-EVAL-TO
    DUP 32 > OVER 0< OR IF
        ERR-L S" shift count " SCR+ DUP SCR-N
        A-SCR A-SCRN @ A-ERR!
    THEN
    63 AND OR 65535 AND
    DUP 1 SWAP A-ONE ;

: A-MODX ( -- )
    A-MBUF A-MNEMN @ S" MDM" STR=
    28672 SWAP A-BITS
    {: op long | a1 u1 a2 u2 hit dest inc obj :}
    long IF 2 ELSE 1 THEN A-ORG !
    A-DEFINE
    A-OPB A-OPN @ SPLIT-COMMA TO hit TO u2 TO a2 TO u1 TO a1
    a1 u1 A-EVAL-TO TO dest
    long IF
        A-TAG 0= IF
            hit IF a2 u2 A-EVAL-TO ELSE 0 THEN
            255 AND op OR TO op
        THEN
        op 65535 AND TO op
        dest 65535 AND TO dest
        op 16 LSHIFT dest OR TO obj
        op dest 2 obj A-TWO
    ELSE
        dest A-TAG 0= A-DISP op OR 65535 AND
        DUP 1 SWAP A-ONE
    THEN ;

: A-BRANCH ( -- )
    A-MBUF A-MNEMN @ S" B" STR=
    [CHAR] I A-HAS 0= AND
    [CHAR] L A-HAS 0= AND
    A-LINE @ CELLS A-FORCE + @ 0= AND IF
        28672 0 A-BITS DROP
        1 A-ORG !
        A-DEFINE
        A-OPB A-OPN @ A-EVAL-TO
        A-TAG 0= A-DISP OR 65535 AND
        DUP 1 SWAP A-ONE
        EXIT
    THEN
    18432
    A-MBUF A-MNEMN @ S" BSI" STR= IF DROP 16384 THEN
    A-MBUF A-MNEMN @ S" BZ" STR= IF DROP 18456 THEN
    A-MBUF A-MNEMN @ S" BNZ" STR= IF DROP 18464 THEN
    A-MBUF A-MNEMN @ S" BP" STR= IF DROP 18480 THEN
    A-MBUF A-MNEMN @ S" BNP" STR= IF DROP 18440 THEN
    A-MBUF A-MNEMN @ S" BN" STR= IF DROP 18472 THEN
    A-MBUF A-MNEMN @ S" BOD" STR= IF DROP 18436 THEN
    {: base | forced a1 u1 a2 u2 hit op long dest mask obj :}
    A-MBUF A-MNEMN @ S" BSI" STR= 0= TO forced
    A-OPB A-OPN @ SPLIT-COMMA TO hit TO u2 TO a2 TO u1 TO a1
    hit IF a2 u2 CMASK ELSE 0 THEN TO mask
    base mask OR forced A-BITS TO long TO op
    long IF 2 ELSE 1 THEN A-ORG !
    A-DEFINE
    A-MBUF A-MNEMN @ S" B" STR=
    a1 u1 S" ACCEP" STR= AND
    [CHAR] I A-HAS AND IF A-LC @ A-ACCEPT ! THEN
    a1 u1 A-EVAL-TO TO dest
    long IF
        op 65535 AND TO op
        dest 65535 AND TO dest
        op 16 LSHIFT dest OR TO obj
        op dest 2 obj A-TWO
    ELSE
        dest A-TAG 0= A-DISP op OR 65535 AND
        DUP 1 SWAP A-ONE
    THEN ;

: A-BSS ( -- )
    0 A-ORG !
    A-DEFINE
    A-OPB A-OPN @ A-EVAL-TO
    DUP 0< IF
        ERR-L S" negative BSS" SCR+ A-SCR A-SCRN @ A-ERR!
        DROP EXIT
    THEN
    DUP 0 SWAP 4 A-NONE ;

: A-LIBF ( -- )
    A-DEFINE
    A-OPB A-OPN @ A-KIND
    A-OPB A-OPN @ NAMECODE
    {: kind code :}
    A-NLIB @ A-MAXLIB < IF
        A-LC @ A-NLIB @ CELLS A-LIBA + !
        kind A-NLIB @ CELLS A-LIBK + !
        1 A-NLIB +!
    THEN
    0 A-WDS !
    A-WDS 1 1 3 code 8 A-EMIT ;

: A-LINKW ( -- )
    A-DEFINE
    A-LC @ A-LINK !
    A-OPB A-OPN @ NAMECODE
    {: code :}
    code 16 RSHIFT 65535 AND
    code 65535 AND
    0 0 2 code A-FOUR ;

: A-ENCODE ( -- )
    A-MBUF A-MNEMN @ S" ABS" STR= IF EXIT THEN
    A-MBUF A-MNEMN @ S" ORG" STR= IF
        0 A-ORG !
        A-OPB A-OPN @ A-EVAL-TO 65535 AND A-LC ! EXIT
    THEN
    A-MBUF A-MNEMN @ S" END" STR= IF
        0 A-ORG !
        A-DEFINE
        A-OPB A-OPN @ A-EVAL-TO 65535 AND DUP A-ENTRY !
        0 0 ROT 4 A-NONE EXIT
    THEN
    A-MBUF A-MNEMN @ S" DC" STR= IF
        1 A-ORG !
        A-DEFINE
        A-OPB A-OPN @ A-EVAL-TO 65535 AND
        DUP 1 SWAP A-ONE EXIT
    THEN
    A-MBUF A-MNEMN @ S" BSS" STR= IF A-BSS EXIT THEN
    A-MBUF A-MNEMN @ S" LIBF" STR= IF A-LIBF EXIT THEN
    A-MBUF A-MNEMN @ S" LINK" STR= IF A-LINKW EXIT THEN
    A-MBUF A-MNEMN @ S" NOP" STR= IF
        A-DEFINE 4096 DUP 1 SWAP A-ONE EXIT THEN
    A-MBUF A-MNEMN @ S" SLA" STR= IF 4096 A-SHIFT EXIT THEN
    A-MBUF A-MNEMN @ S" SLT" STR= IF 4224 A-SHIFT EXIT THEN
    A-MBUF A-MNEMN @ S" SRA" STR= IF 6144 A-SHIFT EXIT THEN
    A-MBUF A-MNEMN @ S" SRT" STR= IF 6272 A-SHIFT EXIT THEN
    A-MBUF A-MNEMN @ S" MDX" STR= IF A-MODX EXIT THEN
    A-MBUF A-MNEMN @ S" MDM" STR= IF A-MODX EXIT THEN
    A-MBUF A-MNEMN @ S" B" STR= IF A-BRANCH EXIT THEN
    A-MBUF A-MNEMN @ S" BSI" STR= IF A-BRANCH EXIT THEN
    A-MBUF A-MNEMN @ S" BZ" STR= IF A-BRANCH EXIT THEN
    A-MBUF A-MNEMN @ S" BNZ" STR= IF A-BRANCH EXIT THEN
    A-MBUF A-MNEMN @ S" BP" STR= IF A-BRANCH EXIT THEN
    A-MBUF A-MNEMN @ S" BNP" STR= IF A-BRANCH EXIT THEN
    A-MBUF A-MNEMN @ S" BN" STR= IF A-BRANCH EXIT THEN
    A-MBUF A-MNEMN @ S" BOD" STR= IF A-BRANCH EXIT THEN
    A-MBUF A-MNEMN @ STD-OP IF A-STD EXIT THEN
    ERR-L S" unknown opcode " SCR+
    A-MBUF A-MNEMN @ SCR+
    A-SCR A-SCRN @ A-ERR! ;

: TOBUF ( a u dest max -- n )
    {: a u dest max | s n :}
    a u -LEADING -TRAILING TO n TO s
    n max MIN TO n
    s dest n MOVE
    n ;

: SLICE ( a u from n -- a2 u2 )
    {: a u from n :}
    from u >= IF 0 0
    ELSE a from +  u from - n MIN THEN ;

: A-OPER ( a u -- )
    {: a u | i :}
    u 35 < IF
        0 A-OPN !
    ELSE a 34 + C@ BL = IF
        0 A-OPN !
    ELSE
        34 TO i
        BEGIN i 72 < i u < AND a i + C@ BL <> AND WHILE
            i 1+ TO i
        REPEAT
        a 34 + i 34 - A-OPB 40 TOBUF A-OPN !
    THEN THEN ;

: A-PARSE ( a u line -- )
    A-LINE !
    DUP 0= IF 2DROP EXIT THEN
    \ A // card. The flag stays under the address, so the second
    \ character is 2 PICK, not OVER.
    DUP 1 > IF
        OVER C@ 47 = 2 PICK 1+ C@ 47 = AND IF 2DROP EXIT THEN
    THEN
    OVER C@ 42 = IF 2DROP EXIT THEN
    DUP 20 > IF OVER 20 + C@ 42 = IF 2DROP EXIT THEN THEN
    2DUP 20 5 SLICE A-LAB 8 TOBUF A-LABN !
    2DUP 26 4 SLICE A-MBUF 8 TOBUF A-MNEMN !
    2DUP 31 2 SLICE A-MODB 4 TOBUF A-MODN !
    A-OPER
    A-MNEMN @ 0= IF
        A-LABN @ IF A-DEFINE THEN
        EXIT
    THEN
    A-ENCODE ;

: NEXT-LINE ( a u -- la lu ra ru flag )
    {: a u | cut :}
    u 0= IF a 0 a 0 FALSE
    ELSE
        -1 TO cut
        u 0 ?DO a I + C@ 10 = IF I TO cut LEAVE THEN LOOP
        cut 0< IF a u a u + 0 TRUE
        ELSE a cut  a cut 1+ +  u cut 1+ - TRUE THEN
    THEN ;

: A-WALK ( -- )
    A-SRC @ A-PA !
    A-SU @ A-PU !
    1 A-LN !
    BEGIN A-PA @ A-PU @ NEXT-LINE WHILE
        2SWAP A-LN @ A-PARSE
        A-PU ! A-PA !
        1 A-LN +!
    REPEAT
    2DROP 2DROP ;

: A-RESET ( -- )
    0 A-NERR ! 0 A-NSYM ! 0 A-NREC ! 0 A-NLIB !
    0 A-ENTRY ! 0 A-LINK ! 0 A-ACCEPT ! 0 A-RETRY !
    65536 A-LO ! -1 A-HI !
    A-IMAGE A-MEM CELLS ERASE ;

: ASSEMBLE ( a u -- )
    A-SU ! A-SRC !
    A-FORCE 800 CELLS ERASE
    1 A-ORG !
    1 A-TRY !
    BEGIN A-TRY @ 6 <= WHILE
        A-RESET
        1 A-PASS ! 0 A-LC ! A-WALK
        A-NERR @ IF EXIT THEN
        2 A-PASS ! 0 A-LC ! A-WALK
        A-RETRY @ 0= IF EXIT THEN
        1 A-TRY +!
    REPEAT ;

: A-.ERRS ( -- )
    A-NERR @ A-MAXERR MIN 0 ?DO
        A-ERR I A-ERRW * + COUNT TYPE CR
    LOOP
    A-NERR @ . ." assembler error(s)" CR ;

\ Listing pages. The first object line for an address is the one that counts.
4096 CONSTANT L-MAX
CREATE L-ON L-MAX CELLS ALLOT
CREATE L-REL L-MAX CELLS ALLOT
CREATE L-OBJ L-MAX CELLS ALLOT
CREATE L-WID L-MAX CELLS ALLOT
CREATE L-HIT L-MAX CELLS ALLOT
VARIABLE L-BAD

: HEX? ( c -- flag )
    DUP 48 58 WITHIN OVER 65 71 WITHIN OR SWAP 97 103 WITHIN OR ;
: HEXVAL ( a u -- n )
    \ The address stays under the accumulator. ROT would fetch from address 0.
    {: a u | n c :}
    0 TO n
    u 0 ?DO
        n 4 LSHIFT
        a I + C@ TO c
        c 48 58 WITHIN IF c 48 - ELSE
        c 65 71 WITHIN IF c 55 - ELSE
        c 97 103 WITHIN IF c 87 - ELSE
        0 THEN THEN THEN
        + TO n
    LOOP
    n ;
: ALLHEX ( a u -- flag )
    DUP 0= IF 2DROP FALSE EXIT THEN
    0 ?DO DUP I + C@ HEX? 0= IF DROP FALSE UNLOOP EXIT THEN LOOP
    DROP TRUE ;

: RELID ( a u -- id )
    DUP 0= IF 2DROP 0 EXIT THEN
    2DUP S" 0" STR= IF 2DROP 1 EXIT THEN
    2DUP S" 00" STR= IF 2DROP 2 EXIT THEN
    2DUP S" 20" STR= IF 2DROP 3 EXIT THEN
    2DROP 9 ;

: L-LINE ( a u -- )
    {: a u | i addr t1 n1 t2 n2 nt rel obj wid :}
    u 4 >= IF
        a 4 ALLHEX IF
            u 4 = IF -1 ELSE a 4 + C@ BL = THEN IF
                a 4 HEXVAL TO addr
                addr 2304 >= addr L-MAX < AND IF
                    4 TO i
                    0 TO nt
                    BEGIN i u < a i + C@ BL = AND WHILE i 1+ TO i REPEAT
                    i u < IF
                        i TO t1
                        BEGIN i u < a i + C@ BL <> AND WHILE i 1+ TO i REPEAT
                        i t1 - TO n1
                        1 TO nt
                        BEGIN i u < a i + C@ BL = AND WHILE i 1+ TO i REPEAT
                        i u < IF
                            i TO t2
                            BEGIN i u < a i + C@ BL <> AND WHILE i 1+ TO i REPEAT
                            i t2 - TO n2
                            2 TO nt
                        THEN
                        a t1 + n1 ALLHEX IF
                            nt 2 = n1 2 <= AND IF
                                a t2 + n2 ALLHEX n2 4 = n2 8 = OR AND IF
                                    a t1 + n1 RELID TO rel
                                    a t2 + n2 HEXVAL TO obj
                                    n2 TO wid
                                    addr CELLS L-ON + @ 0= IF
                                        -1 addr CELLS L-ON + !
                                        rel addr CELLS L-REL + !
                                        obj addr CELLS L-OBJ + !
                                        wid addr CELLS L-WID + !
                                    THEN
                                THEN
                            ELSE
                                n1 4 = n1 8 = OR IF
                                    0 TO rel
                                    a t1 + n1 HEXVAL TO obj
                                    n1 TO wid
                                    addr CELLS L-ON + @ 0= IF
                                        -1 addr CELLS L-ON + !
                                        rel addr CELLS L-REL + !
                                        obj addr CELLS L-OBJ + !
                                        wid addr CELLS L-WID + !
                                    THEN
                                THEN
                            THEN
                        THEN
                    THEN
                THEN
            THEN
        THEN
    THEN ;

: L-TEXT ( a u -- )
    BEGIN NEXT-LINE WHILE
        2SWAP L-LINE
    REPEAT
    2DROP 2DROP ;

: .REL ( id -- )
    DUP 1 = IF DROP ." 0" EXIT THEN
    DUP 2 = IF DROP ." 00" EXIT THEN
    DUP 3 = IF DROP ." 20" EXIT THEN
    DROP ;
: .OBJ ( n wid -- )
    DUP 8 = IF
        DROP DUP 16 RSHIFT .H4 65535 AND .H4
    ELSE
        DROP 65535 AND .H4
    THEN ;
: .MNEM ( packed len -- )
    {: p n :}
    n 0 ?DO p  n 1- I -  8 * RSHIFT 255 AND EMIT LOOP ;

: L-RESET ( -- )
    L-ON L-MAX CELLS ERASE
    L-HIT L-MAX CELLS ERASE
    0 L-BAD ! ;

\ One record is six cells: address, reloc, object, width, mnemonic, length.
\ Locals are not used in this loop. A {: :} frame is popped only when the
\ colon word returns, so a frame inside DO fills the 16-frame table.
VARIABLE C-REC
: C-ADDR ( -- n ) C-REC @ @ ;
: C-REL ( -- n ) C-REC @ CELL+ @ ;
: C-OBJ ( -- n ) C-REC @ 2 CELLS + @ ;
: C-WID ( -- n ) C-REC @ 3 CELLS + @ ;
: C-PACK ( -- n ) C-REC @ 4 CELLS + @ ;
: C-LEN ( -- n ) C-REC @ 5 CELLS + @ ;
: COMPARE-LISTING ( a u -- mismatches )
    L-RESET
    L-TEXT
    A-NREC @ 0 ?DO
        I 6 * CELLS A-RECS + C-REC !
        C-ADDR 0 L-MAX WITHIN IF
            -1 C-ADDR CELLS L-HIT + !
            C-ADDR CELLS L-ON + @ 0= IF
                1 L-BAD +!
                L-BAD @ 30 <= IF
                    C-ADDR .H4 SPACE
                    C-PACK C-LEN .MNEM
                    ."  has no listing line" CR
                THEN
            ELSE
                C-REL C-ADDR CELLS L-REL + @ <>
                C-OBJ C-ADDR CELLS L-OBJ + @ <> OR
                C-WID C-ADDR CELLS L-WID + @ <> OR IF
                    1 L-BAD +!
                    L-BAD @ 30 <= IF
                        C-ADDR .H4 SPACE
                        C-PACK C-LEN .MNEM
                        ." : assembled "
                        C-REL .REL SPACE
                        C-OBJ C-WID .OBJ
                        ." , listing "
                        C-ADDR CELLS L-REL + @ .REL SPACE
                        C-ADDR CELLS L-OBJ + @ C-ADDR CELLS L-WID + @ .OBJ
                        CR
                    THEN
                THEN
            THEN
        THEN
    LOOP
    L-MAX 0 ?DO
        I CELLS L-ON + @ IF
            I CELLS L-HIT + @ 0= IF
                1 L-BAD +!
                L-BAD @ 30 <= IF
                    I .H4 ."  is in the listing but was not assembled" CR
                THEN
            THEN
        THEN
    LOOP
    L-BAD @
    DUP 0> IF DUP . ." listing mismatch(es)" CR THEN ;

: A-LIB? ( addr -- kind true | false )
    A-NLIB @ 0 ?DO
        DUP I CELLS A-LIBA + @ = IF
            DROP I CELLS A-LIBK + @ TRUE UNLOOP EXIT
        THEN
    LOOP
    DROP FALSE ;

: A-SYM ( a u -- n true | false ) A-FIND ;
