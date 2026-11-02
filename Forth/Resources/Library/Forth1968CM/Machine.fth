DECIMAL

\ M-ASCII maps a console code to a character. 255 means ignore, 0 means show ?.
\ M-CIN maps a host ASCII code to an 1130 key code. 0 means the key is not used.
\ M-GLYPH is the ASCII character for each of the 64 Selectric positions.
\ M-SPEC holds the Selectric codes for the punctuation positions.
\ M-FBIT marks opcodes whose format bit selects a long instruction.
CREATE M-ASCII
    46 C, 255 C, 162 C, 10 C, 64 C, 255 C, 37 C, 0 C, 0 C, 255 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
    70 C, 8 C, 102 C, 0 C, 71 C, 0 C, 103 C, 0 C, 66 C, 0 C, 98 C, 0 C, 67 C, 0 C, 99 C, 0 C,
    73 C, 32 C, 105 C, 0 C, 72 C, 0 C, 104 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
    68 C, 0 C, 100 C, 0 C, 69 C, 0 C, 101 C, 0 C, 0 C, 0 C, 0 C, 0 C, 65 C, 0 C, 97 C, 0 C,
    36 C, 9 C, 33 C, 0 C, 38 C, 0 C, 62 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
    79 C, 0 C, 111 C, 0 C, 80 C, 0 C, 111 C, 0 C, 75 C, 0 C, 107 C, 0 C, 76 C, 0 C, 108 C, 0 C,
    82 C, 0 C, 114 C, 0 C, 81 C, 0 C, 113 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
    77 C, 0 C, 109 C, 0 C, 78 C, 0 C, 110 C, 0 C, 0 C, 0 C, 0 C, 0 C, 74 C, 0 C, 106 C, 0 C,
    44 C, 13 C, 58 C, 0 C, 45 C, 0 C, 63 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
    87 C, 0 C, 119 C, 0 C, 88 C, 0 C, 120 C, 0 C, 83 C, 0 C, 115 C, 0 C, 84 C, 0 C, 116 C, 0 C,
    90 C, 0 C, 122 C, 0 C, 89 C, 0 C, 121 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
    85 C, 0 C, 117 C, 0 C, 86 C, 0 C, 118 C, 0 C, 0 C, 0 C, 0 C, 0 C, 47 C, 0 C, 95 C, 0 C,
    35 C, 0 C, 61 C, 0 C, 48 C, 0 C, 124 C, 0 C, 0 C, 0 C, 0 C, 0 C, 74 C, 0 C, 106 C, 0 C,
    54 C, 0 C, 59 C, 0 C, 55 C, 0 C, 42 C, 0 C, 50 C, 0 C, 43 C, 0 C, 51 C, 0 C, 60 C, 0 C,
    57 C, 0 C, 34 C, 0 C, 56 C, 0 C, 39 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
    52 C, 0 C, 172 C, 0 C, 53 C, 0 C, 41 C, 0 C, 0 C, 0 C, 0 C, 0 C, 49 C, 0 C, 40 C, 0 C,
CREATE M-CIN
    0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 ,
    4 , 0 , 0 , 0 , 0 , 8 , 0 , 0 ,
    0 , 0 , 34848 , 0 , 0 , 2 , 0 , 0 ,
    0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 ,
    1 , 18464 , 96 , 1056 , 17440 , 8736 , 32768 , 288 ,
    33056 , 16672 , 16928 , 32928 , 9248 , 16384 , 33824 , 12288 ,
    8192 , 4096 , 2048 , 1024 , 512 , 256 , 128 , 64 ,
    32 , 16 , 2080 , 16544 , 33312 , 160 , 8352 , 8288 ,
    544 , 36864 , 34816 , 33792 , 33280 , 33024 , 32896 , 32832 ,
    32800 , 32784 , 20480 , 18432 , 17408 , 16896 , 16640 , 16512 ,
    16448 , 16416 , 16400 , 10240 , 9216 , 8704 , 8448 , 8320 ,
    8256 , 8224 , 8208 , 0 , 0 , 0 , 0 , 8480 ,
    0 , 36864 , 34816 , 33792 , 33280 , 33024 , 32896 , 32832 ,
    32800 , 32784 , 20480 , 18432 , 17408 , 16896 , 16640 , 16512 ,
    16448 , 16416 , 16400 , 10240 , 9216 , 8704 , 8448 , 8320 ,
    8256 , 8224 , 8208 , 0 , 45152 , 0 , 0 , 4 ,
CREATE M-GLYPH
    48 C, 49 C, 50 C, 51 C, 52 C, 53 C, 54 C, 55 C, 56 C, 57 C, 65 C, 66 C, 67 C, 68 C, 69 C, 70 C,
    71 C, 72 C, 73 C, 74 C, 75 C, 76 C, 77 C, 78 C, 79 C, 80 C, 81 C, 82 C, 83 C, 84 C, 85 C, 86 C,
    87 C, 88 C, 89 C, 90 C, 32 C, 1 C, 35 C, 60 C, 40 C, 43 C, 124 C, 38 C, 33 C, 36 C, 42 C, 41 C,
    59 C, 2 C, 45 C, 47 C, 44 C, 37 C, 95 C, 62 C, 63 C, 58 C, 46 C, 64 C, 39 C, 61 C, 34 C, 32 C,
CREATE M-SPEC
    64 C, 74 C, 123 C, 76 C, 77 C, 78 C, 79 C, 80 C, 90 C, 91 C, 92 C, 93 C, 94 C, 95 C,
    96 C, 97 C, 107 C, 108 C, 109 C, 110 C, 111 C, 122 C, 75 C, 124 C, 125 C, 126 C, 127 C, 64 C,
CREATE M-FBIT
    0 C, 1 C, 0 C, 0 C, 0 C, 1 C, 0 C, 0 C, 1 C, 1 C, 0 C, 0 C, 1 C, 1 C, 1 C, 0 C,
    1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C,

\ IBM 1130 CPU, disk, and Selectric console for the 1968 Forth kernel.
\ Index registers are memory words 1, 2 and 3. LIBF is trapped.
\ Keyboard input comes from KEY. End of input is throw -21.

DECIMAL

DOC" M-MEMN ( -- n ) 1130 memory size in words"
32768 CONSTANT M-MEMN

DOC" M-SLOTS ( -- n ) number of cached disk sectors"
128 CONSTANT M-SLOTS

DOC" M-MIN ( a b -- n ) lesser of a and b"
: M-MIN ( a b -- n ) 2DUP < IF DROP ELSE NIP THEN ;

DOC" SEX8 ( n -- n ) sign-extend an 8-bit displacement"
: SEX8 ( n -- n ) 255 AND DUP 128 AND IF 256 - THEN ;

DOC" SEX16 ( n -- n ) sign-extend a 16-bit word"
: SEX16 ( n -- n ) 65535 AND DUP 32768 AND IF 65536 - THEN ;

DOC" M-MEM ( -- addr ) 1130 memory, one host cell per 16-bit word"
CREATE M-MEM M-MEMN CELLS ALLOT

DOC" M-SID ( -- addr ) sector number for each cache slot"
CREATE M-SID M-SLOTS CELLS ALLOT

DOC" M-SDAT ( -- addr ) cached sector bodies, 320 words each"
CREATE M-SDAT M-SLOTS 320 * CELLS ALLOT

DOC" M-CODES ( -- addr ) Selectric tilt/rotate code for each glyph"
CREATE M-CODES 64 CELLS ALLOT

DOC" M-KEYS ( -- addr ) queued 1130 key codes"
CREATE M-KEYS 256 CELLS ALLOT

DOC" M-XLOG ( -- addr ) trace buffer: device, function, modifier, address, IAR"
CREATE M-XLOG 40 5 * CELLS ALLOT

DOC" M-TRAIL ( -- addr ) recent instruction addresses and opcodes"
CREATE M-TRAIL 48 CELLS ALLOT

DOC" M-RING ( -- addr ) recent program counters, used to spot a stuck loop"
CREATE M-RING 48 CELLS ALLOT

DOC" M-CON ( -- addr ) Selectric console output waiting to be printed"
CREATE M-CON 128 ALLOT

DOC" M-LINEB ( -- addr ) one printer line, decoded from Selectric codes"
CREATE M-LINEB 160 ALLOT

DOC" M-ACCBUF ( -- addr ) characters the 1968 interpreter accepted"
CREATE M-ACCBUF 400 ALLOT

DOC" M-WHY ( -- addr ) counted string: why the 1130 stopped"
CREATE M-WHY 80 ALLOT

DOC" M-IAR ( -- a-addr ) instruction address register"
VARIABLE M-IAR

DOC" M-ACC ( -- a-addr ) accumulator, low 16 bits"
VARIABLE M-ACC

DOC" M-EXT ( -- a-addr ) extension, low half of a double word"
VARIABLE M-EXT

DOC" M-CARRY ( -- a-addr ) carry flag"
VARIABLE M-CARRY

DOC" M-OVF ( -- a-addr ) overflow flag"
VARIABLE M-OVF

DOC" M-WS ( -- a-addr ) memory address of the accepted-source word"
VARIABLE M-WS

DOC" M-HALT ( -- a-addr ) true after the machine stops"
VARIABLE M-HALT

DOC" M-HI ( -- a-addr ) true after the console prints HI THERE"
VARIABLE M-HI

DOC" M-STEPS ( -- a-addr ) instructions executed"
VARIABLE M-STEPS

DOC" M-LIM ( -- a-addr ) step limit passed to M-RUN"
VARIABLE M-LIM

DOC" M-KBUSY ( -- a-addr ) console is waiting for a key"
VARIABLE M-KBUSY

DOC" M-PDONE ( -- a-addr ) console printer operation has finished"
VARIABLE M-PDONE

DOC" M-KEY ( -- a-addr ) key code ready for the console"
VARIABLE M-KEY

DOC" M-KEYF ( -- a-addr ) true when M-KEY holds a code"
VARIABLE M-KEYF

DOC" M-KN ( -- a-addr ) number of codes stored in M-KEYS"
VARIABLE M-KN

DOC" M-KR ( -- a-addr ) next M-KEYS index to read"
VARIABLE M-KR

DOC" M-NSLOT ( -- a-addr ) how many disk sectors are cached"
VARIABLE M-NSLOT

DOC" M-XN ( -- a-addr ) how many XIO entries are in M-XLOG"
VARIABLE M-XN

DOC" M-TAT ( -- a-addr ) next slot in the instruction trail"
VARIABLE M-TAT

DOC" M-RAT ( -- a-addr ) next slot in the program-counter ring"
VARIABLE M-RAT

DOC" M-HOT ( -- a-addr ) how many checks saw a short repeated loop"
VARIABLE M-HOT

DOC" M-CLEN ( -- a-addr ) characters waiting in M-CON"
VARIABLE M-CLEN

DOC" M-LLEN ( -- a-addr ) characters waiting in M-LINEB"
VARIABLE M-LLEN

DOC" M-ACCN ( -- a-addr ) characters stored in M-ACCBUF"
VARIABLE M-ACCN

DOC" M-ACOL ( -- a-addr ) column of the accepted source line"
VARIABLE M-ACOL

DOC" M-NREAD ( -- a-addr ) disk sectors read"
VARIABLE M-NREAD

DOC" M-LI ( -- a-addr ) source line number while packing FO.FO"
VARIABLE M-LI

DOC" M-PC ( -- a-addr ) address of the instruction being executed"
VARIABLE M-PC

DOC" M-IR ( -- a-addr ) bits of the instruction being executed"
VARIABLE M-IR

DOC" M-TAG ( -- a-addr ) index-register field, 0 through 3"
VARIABLE M-TAG

DOC" M-LONG ( -- a-addr ) true when the instruction has a second word"
VARIABLE M-LONG

DOC" M-W2 ( -- a-addr ) second word of a long instruction"
VARIABLE M-W2

DOC" M-CNT ( -- a-addr ) shift count or disk-transfer count"
VARIABLE M-CNT

DOC" M-CTRL ( -- a-addr ) address of the disk control word"
VARIABLE M-CTRL

DOC" M-DAT ( -- a-addr ) address of the cached sector being transferred"
VARIABLE M-DAT

DOC" M@ ( addr -- w ) fetch one 16-bit 1130 word"
: M@ ( addr -- w ) 32767 AND CELLS M-MEM + @ 65535 AND ;

DOC" M! ( w addr -- ) store one 16-bit 1130 word"
: M! ( w addr -- ) 32767 AND CELLS M-MEM + SWAP 65535 AND SWAP ! ;

DOC" M-IAR+ ( n -- ) add n to the instruction address, keep 15 bits"
: M-IAR+ ( n -- ) M-IAR @ + 32767 AND M-IAR ! ;

DOC" M-ABC ( -- ) build the 64 Selectric tilt/rotate codes"
: M-ABC ( -- )
    64 0 DO
        I 10 < IF 240 I +
        ELSE I 19 < IF 193 I 10 - +
        ELSE I 28 < IF 209 I 19 - +
        ELSE I 36 < IF 226 I 28 - +
        ELSE I 36 - M-SPEC + C@
        THEN THEN THEN THEN
        I CELLS M-CODES + !
    LOOP ;

DOC" M-ENC ( c -- code ) ASCII character to a Selectric code, or 64"
: M-ENC ( c -- code )
    64 0 DO
        DUP I M-GLYPH + C@ = IF
            DROP I CELLS M-CODES + @ UNLOOP EXIT
        THEN
    LOOP
    DROP 64 ;

DOC" M-DEC ( code -- c ) Selectric code to ASCII, or blank"
: M-DEC ( code -- c )
    64 0 DO
        I CELLS M-CODES + @ OVER = IF
            DROP I M-GLYPH + C@ UNLOOP EXIT
        THEN
    LOOP
    DROP 32 ;

DOC" M-FIND ( sector -- addr true | false ) cached buffer for a sector"
: M-FIND ( sector -- addr true | false )
    M-NSLOT @ 0 ?DO
        I CELLS M-SID + @ OVER = IF
            DROP I 320 * CELLS M-SDAT + TRUE UNLOOP EXIT
        THEN
    LOOP
    DROP FALSE ;

DOC" M-ALLOC ( sector -- addr ) find or reserve a sector buffer of blanks"
: M-ALLOC ( sector -- addr )
    DUP M-FIND IF NIP EXIT THEN
    M-NSLOT @ M-SLOTS >= IF DROP M-SDAT EXIT THEN
    M-NSLOT @ CELLS M-SID + !
    M-NSLOT @ 320 * CELLS M-SDAT +
    320 0 DO 16448 OVER I CELLS + ! LOOP
    1 M-NSLOT +! ;

DOC" M-SRC ( a u i -- c ) character i of a string, or blank past column 71"
: M-SRC ( a u i -- c )
    DUP 71 > IF DROP 2DROP 32 EXIT THEN
    OVER OVER SWAP >= IF DROP 2DROP 32 EXIT THEN
    SWAP DROP + C@ ;

DOC" M-PACK1 ( a u index -- ) pack one source line onto the disk image"
: M-PACK1 ( a u index -- )
    {: a u index | sec data base w :}
    index 8 / 4334 + TO sec
    7 index 8 MOD - 40 * TO base
    sec M-ALLOC TO data
    40 0 DO
        a u I 2* M-SRC M-ENC 8 LSHIFT
        a u I 2* 1+ M-SRC M-ENC OR TO w
        w data base 39 I - + CELLS + !
    LOOP ;

DOC" M-PACK ( a u -- ) split the deck into lines and pack each line"
: M-PACK ( a u -- )
    0 M-NSLOT !
    0 M-LI !
    BEGIN NEXT-LINE WHILE
        2SWAP M-LI @ M-PACK1
        1 M-LI +!
    REPEAT
    2DROP 2DROP ;

DOC" M-LC ( c -- ) append one character to the printer line"
: M-LC ( c -- )
    M-LLEN @ 159 < IF
        M-LLEN @ M-LINEB + C!
        1 M-LLEN +!
    ELSE DROP THEN ;

DOC" M-FIRST ( -- ) print disk sector 4334, the first Forth record"
: M-FIRST ( -- )
    4334 M-FIND 0= IF EXIT THEN
    0 M-LLEN !
    36 0 DO
        DUP 319 I - CELLS + @
        DUP 8 RSHIFT 255 AND M-DEC M-LC
        255 AND M-DEC M-LC
    LOOP
    DROP
    M-LINEB M-LLEN @ -LEADING -TRAILING TYPE CR ;

DOC" M-APPEND ( c -- ) append one character to the console buffer"
: M-APPEND ( c -- )
    M-CLEN @ 127 < IF
        M-CLEN @ M-CON + C!
        1 M-CLEN +!
    ELSE DROP THEN ;

DOC" M-FLUSH ( -- ) print the console buffer; notice HI THERE"
: M-FLUSH ( -- )
    M-CON M-CLEN @ -LEADING -TRAILING
    DUP 0= IF 2DROP 0 M-CLEN ! EXIT THEN
    2DUP S" HI THERE" SEARCH >R 2DROP R> IF -1 M-HI ! THEN
    TYPE CR
    0 M-CLEN ! ;

DOC" M-OUTC ( c -- ) emit one character, as UTF-8 when it is above 127"
: M-OUTC ( c -- )
    DUP 128 < IF EMIT EXIT THEN
    DUP 6 RSHIFT 192 OR EMIT
    63 AND 128 OR EMIT ;

DOC" M-EMITCON ( code -- ) decode one console code into the console buffer"
: M-EMITCON ( code -- )
    255 AND
    DUP 1 AND IF
        12 INVERT AND
        DUP 1 INVERT AND 0= IF DROP EXIT THEN
    THEN
    M-ASCII + C@
    DUP 255 = IF DROP EXIT THEN
    DUP 0= IF DROP 63 M-APPEND
    ELSE DUP 13 = OVER 10 = OR IF DROP M-FLUSH
    ELSE DUP 8 = OVER 9 = OR IF DROP
    ELSE M-APPEND
        M-CLEN @ 120 >= IF M-FLUSH THEN
    THEN THEN THEN ;

DOC" M-PUSH ( code -- ) queue one 1130 key code"
: M-PUSH ( code -- )
    M-KN @ 256 < IF
        M-KN @ CELLS M-KEYS + !
        1 M-KN +!
    ELSE DROP THEN ;

DOC" M-MAP ( ascii -- code true | false ) host key to an 1130 code"
: M-MAP ( ascii -- code true | false )
    DUP 10 = OVER 13 = OR OVER 32 = OR IF DROP 0 TRUE EXIT THEN
    DUP 8 = OVER 127 = OR IF
        DROP
        M-KN @ IF -1 M-KN +! THEN
        FALSE EXIT
    THEN
    DUP 0 128 WITHIN 0= IF DROP FALSE EXIT THEN
    CELLS M-CIN + @
    DUP 0= IF DROP FALSE EXIT THEN
    65534 AND TRUE ;

DOC" M-FILL ( -- flag ) read host keys until Return; false at end of input"
: M-FILL ( -- flag )
    0 M-KN ! 0 M-KR !
    M-FLUSH
    BEGIN
        ['] KEY CATCH ?DUP IF
            DUP -21 = IF
                DROP
                M-KN @ IF
                    M-KN @ 1- CELLS M-KEYS + @ IF 0 M-PUSH THEN
                    TRUE
                ELSE
                    FALSE
                THEN
                EXIT
            THEN
            THROW
        THEN
        DUP 10 = OVER 13 = OR IF
            DROP 0 M-PUSH
            TRUE EXIT
        THEN
        M-MAP IF M-PUSH THEN
    AGAIN ;

DOC" M-TAKE ( -- code true | false ) next queued key, reading a line if needed"
: M-TAKE ( -- code true | false )
    BEGIN
        M-KR @ M-KN @ < IF
            M-KR @ CELLS M-KEYS + @
            1 M-KR +!
            TRUE EXIT
        THEN
        M-FILL 0= IF FALSE EXIT THEN
    AGAIN ;

DOC" M-STOP ( a u -- ) store a halt reason and stop the machine"
: M-STOP ( a u -- )
    M-HALT @ IF 2DROP EXIT THEN
    70 M-MIN M-WHY PLACE
    -1 M-HALT ! ;

DOC" M-H4 ( n -- ) append n as four hex digits to the halt reason"
: M-H4 ( n -- )
    4 0 DO
        DUP 12 I 4 * - RSHIFT 15 AND
        DUP 10 < IF 48 ELSE 55 THEN +
        M-WHY C@ 78 < IF
            M-WHY COUNT + C!
            M-WHY C@ 1+ M-WHY C!
        ELSE DROP THEN
    LOOP
    DROP ;

DOC" M-WHYS ( a u -- ) append text to the halt reason"
: M-WHYS ( a u -- )
    0 ?DO
        DUP I + C@
        M-WHY C@ 78 < IF
            M-WHY COUNT + C!
            M-WHY C@ 1+ M-WHY C!
        ELSE DROP THEN
    LOOP
    DROP ;

DOC" M-STOPH ( n a u -- ) halt with text and a four-digit hex address"
: M-STOPH ( n a u -- )
    M-HALT @ IF DROP 2DROP EXIT THEN
    ROT >R
    70 M-MIN M-WHY PLACE
    R> M-H4
    -1 M-HALT ! ;

DOC" M-READ ( ctrl -- ) copy a cached sector into 1130 memory"
: M-READ ( ctrl -- )
    DUP M-CTRL !
    M@ 320 M-MIN M-CNT !
    M-CTRL @ 1+ M@ M-ALLOC M-DAT !
    M-CNT @ 0 ?DO
        M-DAT @ I CELLS + @
        M-CTRL @ I 2 + + M!
    LOOP
    1 M-NREAD +! ;

DOC" M-DWRITE ( addr -- ) copy 1130 memory back into the cached sector"
: M-DWRITE ( addr -- )
    DUP M-CTRL !
    M@ 320 M-MIN M-CNT !
    M-CTRL @ 1+ M@ M-ALLOC M-DAT !
    M-CNT @ 0 ?DO
        M-CTRL @ I 2 + + M@
        M-DAT @ I CELLS + !
    LOOP ;

DOC" M-PRINT ( ctrl -- ) print a Selectric string from memory"
: M-PRINT ( ctrl -- )
    DUP M@ 80 M-MIN
    0 M-LLEN !
    0 ?DO
        DUP 1+ I + M@
        DUP 8 RSHIFT 255 AND M-DEC M-LC
        255 AND M-DEC M-LC
    LOOP
    DROP
    M-LINEB M-LLEN @ -LEADING -TRAILING
    DUP 0= IF 2DROP EXIT THEN
    2DUP S" HI THERE" SEARCH >R 2DROP R> IF -1 M-HI ! THEN
    TYPE CR ;

DOC" M-CXIO ( addr fn mod -- ) console XIO: write, sense, request, or reset"
: M-CXIO ( addr fn mod -- )
    {: addr fn mod :}
    fn 1 = IF
        addr M@ 8 RSHIFT M-EMITCON
        -1 M-PDONE !
    THEN
    fn 2 = IF
        M-KEYF @ IF M-KEY @ ELSE 0 THEN
        addr M!
        0 M-KEYF ! 0 M-KBUSY !
    THEN
    fn 4 = IF
        -1 M-KBUSY ! 0 M-KEYF !
    THEN
    fn 7 = IF
        0 M-ACC !
        mod 1 AND IF 0 M-PDONE ! THEN
    THEN ;

DOC" M-DXIO ( addr fn -- ) disk XIO: function 6 reads, function 5 writes"
: M-DXIO ( addr fn -- )
    DUP 6 = IF DROP M-READ EXIT THEN
    DUP 5 = IF DROP M-DWRITE EXIT THEN
    2DROP 0 M-ACC ! ;

DOC" M-XLOG ( dev fn mod addr -- ) remember one XIO in the trace log"
: M-XLOG ( dev fn mod addr -- )
    M-XN @ 40 >= IF 2DROP 2DROP EXIT THEN
    M-XN @ 5 * CELLS M-XLOG + >R
    R@ 3 CELLS + !
    R@ 2 CELLS + !
    R@ CELL+ !
    R@ !
    M-IAR @ R> 4 CELLS + !
    1 M-XN +! ;

DOC" M-EA ( -- ea ) effective address of the current instruction"
: M-EA ( -- ea )
    M-LONG @ IF
        M-W2 @ 65535 AND
        M-TAG @ IF M-TAG @ M@ + 65535 AND THEN
        M-IR @ 128 AND IF M@ THEN
    ELSE
        M-IR @ SEX8
        M-TAG @ IF M-TAG @ M@ + ELSE M-IAR @ + THEN
        65535 AND
    THEN ;

DOC" M-XIO ( -- ) execute XIO; device 1 is the console, 4 and 17 the disk"
: M-XIO ( -- )
    {: | ea addr ctl dev fn mod :}
    M-EA TO ea
    ea M@ TO addr
    ea 1 OR M@ TO ctl
    0 M-ACC !
    ctl 11 RSHIFT 31 AND TO dev
    ctl 8 RSHIFT 7 AND TO fn
    ctl 255 AND TO mod
    dev fn mod addr M-XLOG
    dev 1 = IF addr fn mod M-CXIO THEN
    dev 4 = dev 17 = OR IF addr fn M-DXIO THEN ;

DOC" M-IRQ ( -- ) interrupt through the console vector at word 12"
: M-IRQ ( -- )
    12 M@
    DUP 2304 32768 WITHIN IF
        DUP M-IAR @ SWAP M!
        1+ 32767 AND M-IAR !
    ELSE
        S" bad console vector " M-STOPH
    THEN ;

DOC" M-WAIT ( -- ) wait for a key or the printer, then interrupt"
: M-WAIT ( -- )
    M-KBUSY @ IF
        M-KEYF @ 0= IF
            M-TAKE 0= IF S" end of input" M-STOP EXIT THEN
            M-KEY ! -1 M-KEYF !
        THEN
        M-IRQ
    ELSE M-PDONE @ IF
        M-IRQ
    ELSE
        M-PC @ 1- 32767 AND M@
        DUP 2304 32768 WITHIN IF
            M-IAR !
        ELSE
            DROP
            M-PC @ S" wait at " M-STOPH
        THEN
    THEN THEN ;

DOC" M-COND ( -- flag ) BSC condition: overflow, carry, even, plus, minus, zero"
: M-COND ( -- flag )
    M-IR @ 1 AND IF
        M-OVF @ 0= IF TRUE EXIT THEN
        0 M-OVF !
    THEN
    M-IR @ 2 AND M-CARRY @ 0= AND IF TRUE EXIT THEN
    M-IR @ 4 AND M-ACC @ 1 AND 0= AND IF TRUE EXIT THEN
    M-IR @ 8 AND M-ACC @ 32768 AND 0= AND M-ACC @ 0<> AND IF TRUE EXIT THEN
    M-IR @ 16 AND M-ACC @ 32768 AND 0<> AND IF TRUE EXIT THEN
    M-IR @ 32 AND M-ACC @ 0= AND IF TRUE EXIT THEN
    FALSE ;

DOC" M-ADD ( src -- ) add src to the accumulator"
: M-ADD ( src -- )
    {: src | old sum :}
    M-ACC @ 65535 AND TO old
    src 65535 AND TO src
    old src + 65535 AND TO sum
    sum src U< M-CARRY !
    M-OVF @ 0= IF
        src INVERT old XOR
        src sum XOR AND
        32768 AND IF -1 M-OVF ! THEN
    THEN
    sum M-ACC ! ;

DOC" M-SUB ( src -- ) subtract src from the accumulator"
: M-SUB ( src -- )
    {: src | old diff :}
    M-ACC @ 65535 AND TO old
    src 65535 AND TO src
    old src - 65535 AND TO diff
    old src U< M-CARRY !
    M-OVF @ 0= IF
        old src XOR
        old diff XOR AND
        32768 AND IF -1 M-OVF ! THEN
    THEN
    diff M-ACC ! ;

DOC" M-DADD ( ea -- ) add the double word at ea into A and the extension"
: M-DADD ( ea -- )
    {: ea | lo cy hi left right sum :}
    M-ACC @ 65535 AND 16 LSHIFT M-EXT @ 65535 AND OR TO left
    ea M@ 65535 AND 16 LSHIFT ea 1 OR M@ 65535 AND OR TO right
    M-EXT @ 65535 AND ea 1 OR M@ 65535 AND +
    DUP 65535 AND TO lo
    65535 U> IF 1 ELSE 0 THEN TO cy
    M-ACC @ 65535 AND ea M@ 65535 AND + cy +
    DUP 65535 AND TO hi
    65535 U> M-CARRY !
    hi 16 LSHIFT lo OR TO sum
    M-OVF @ 0= IF
        left INVERT right XOR
        left sum XOR AND
        1 31 LSHIFT AND IF -1 M-OVF ! THEN
    THEN
    hi M-ACC ! lo M-EXT ! ;

DOC" M-DSUB ( ea -- ) subtract the double word at ea from A and the extension"
: M-DSUB ( ea -- )
    {: ea | lo bo hi left right diff :}
    M-ACC @ 65535 AND 16 LSHIFT M-EXT @ 65535 AND OR TO left
    ea M@ 65535 AND 16 LSHIFT ea 1 OR M@ 65535 AND OR TO right
    M-EXT @ 65535 AND ea 1 OR M@ 65535 AND
    2DUP U< IF 1 ELSE 0 THEN TO bo
    - 65535 AND TO lo
    M-ACC @ 65535 AND ea M@ 65535 AND - bo - 65535 AND TO hi
    left right U< M-CARRY !
    hi 16 LSHIFT lo OR TO diff
    M-OVF @ 0= IF
        left right XOR
        left diff XOR AND
        1 31 LSHIFT AND IF -1 M-OVF ! THEN
    THEN
    hi M-ACC ! lo M-EXT ! ;

DOC" M-MUL ( src -- ) signed multiply; high half to A, low half to extension"
: M-MUL ( src -- )
    SEX16 M-ACC @ SEX16 *
    DUP 16 RSHIFT 65535 AND M-ACC !
    65535 AND M-EXT ! ;

DOC" M-DIV ( src -- ) signed divide of the double word by src"
: M-DIV ( src -- )
    {: src | div d q bad :}
    M-ACC @ 65535 AND 16 LSHIFT M-EXT @ 65535 AND OR TO div
    src SEX16 TO d
    0 TO bad
    d 0= IF -1 TO bad THEN
    div 1 31 LSHIFT = d -1 = AND IF -1 TO bad THEN
    bad IF -1 M-OVF !
    ELSE
        div d / TO q
        q 32767 > q -32768 < OR IF
            -1 M-OVF !
        ELSE
            q 65535 AND M-ACC !
            div d MOD 65535 AND M-EXT !
        THEN
    THEN ;

DOC" M-SHL ( -- ) shift left, one register or the long pair"
: M-SHL ( -- )
    M-TAG @ 0= IF M-IR @ ELSE M-TAG @ M@ THEN 63 AND M-CNT !
    M-IR @ 192 AND 128 = IF
        M-CNT @ 0 ?DO
            M-ACC @ 32768 AND 0<> M-CARRY !
            M-EXT @ 32768 AND 15 RSHIFT
            M-ACC @ 1 LSHIFT 65535 AND OR M-ACC !
            M-EXT @ 1 LSHIFT 65535 AND M-EXT !
        LOOP
    ELSE
        M-CNT @ 0 ?DO
            M-ACC @ 32768 AND 0<> M-CARRY !
            M-ACC @ 1 LSHIFT 65535 AND M-ACC !
        LOOP
    THEN ;

DOC" M-SHR ( -- ) shift right: logical, rotate, or the long pair"
: M-SHR ( -- )
    M-TAG @ 0= IF M-IR @ ELSE M-TAG @ M@ THEN 63 AND M-CNT !
    M-IR @ 192 AND
    DUP 0= IF DROP
        M-CNT @ 16 >= IF 0 M-ACC !
        ELSE M-ACC @ M-CNT @ RSHIFT 65535 AND M-ACC ! THEN
    ELSE DUP 128 = IF DROP
        M-CNT @ 0 ?DO
            M-ACC @ 1 AND 15 LSHIFT
            M-ACC @ 32768 AND
            M-ACC @ 1 RSHIFT 32767 AND OR M-ACC !
            M-EXT @ 1 RSHIFT 32767 AND OR M-EXT !
        LOOP
    ELSE DUP 192 = IF DROP
        M-CNT @ 0 ?DO
            M-EXT @ 1 AND 15 LSHIFT
            M-ACC @ 1 AND 15 LSHIFT
            M-EXT @ 1 RSHIFT 32767 AND OR M-EXT !
            M-ACC @ 1 RSHIFT 32767 AND OR M-ACC !
        LOOP
    ELSE
        DROP S" invalid shift " M-STOP
    THEN THEN THEN ;

DOC" M-MDX ( -- ) add a displacement to an index or a word, then maybe skip"
: M-MDX ( -- )
    {: | old new skip addend :}
    0 TO skip
    M-LONG @ IF
        M-TAG @ IF
            M-IR @ 128 AND IF M-W2 @ M@ ELSE M-W2 @ THEN
            65535 AND TO addend
            M-TAG @ M@ TO old
            old addend + 65535 AND TO new
            new M-TAG @ M!
        ELSE
            M-IR @ SEX8 TO addend
            M-W2 @ M@ TO old
            old addend + 65535 AND TO new
            new M-W2 @ M!
        THEN
        -1 TO skip
    ELSE
        M-TAG @ IF
            M-IR @ SEX8 TO addend
            M-TAG @ M@ TO old
            old addend + 65535 AND TO new
            new M-TAG @ M!
            -1 TO skip
        ELSE
            M-IAR @ M-IR @ SEX8 + 32767 AND M-IAR !
        THEN
    THEN
    skip IF
        new 0= old new XOR 32768 AND OR IF
            1 M-IAR+
        THEN
    THEN ;

DOC" M-LDX ( -- ) load an index register, or the instruction address"
: M-LDX ( -- )
    M-LONG @ IF
        M-IR @ 128 AND IF M-W2 @ M@ ELSE M-W2 @ THEN
    ELSE
        M-IR @ SEX8
    THEN
    65535 AND
    M-TAG @ IF M-TAG @ M! ELSE 32767 AND M-IAR ! THEN ;

DOC" M-STX ( -- ) store an index register, or the instruction address"
: M-STX ( -- )
    M-LONG @ IF
        M-IR @ 128 AND IF M-W2 @ M@ ELSE M-W2 @ THEN
    ELSE
        M-IAR @ M-IR @ SEX8 + 65535 AND
    THEN
    M-TAG @ 0= IF M-IAR @ ELSE M-TAG @ M@ THEN
    SWAP M! ;

DOC" M-REMEMBER ( pc ir -- ) record this instruction for the stuck-loop check"
: M-REMEMBER ( pc ir -- )
    OVER M-RAT @ CELLS M-RING + !
    SWAP M-TAT @ 2 * CELLS M-TRAIL + !
    M-TAT @ 2 * CELLS M-TRAIL + CELL+ !
    M-TAT @ 1+ 24 MOD M-TAT !
    M-RAT @ 1+ 48 MOD M-RAT ! ;

DOC" M-NOTE ( -- ) save one accepted source character from the word at M-WS"
: M-NOTE ( -- )
    M-ACCN @ 390 >= IF EXIT THEN
    M-WS @ M@
    DUP 0 64 WITHIN IF M-GLYPH + C@ ELSE DROP 63 THEN
    DUP 1 = OVER 2 = OR IF DROP 63 THEN
    M-ACCN @ M-ACCBUF + C!
    1 M-ACCN +!
    1 M-ACOL +!
    M-ACOL @ 72 = IF
        0 M-ACOL !
        10 M-ACCN @ M-ACCBUF + C!
        1 M-ACCN +!
    THEN ;

DOC" M-BAD ( -- ) halt on an opcode this simulator does not implement"
: M-BAD ( -- )
    M-HALT @ IF EXIT THEN
    S" invalid opcode " M-WHY PLACE
    M-IR @ M-H4
    S"  at " M-WHYS
    M-PC @ M-H4
    -1 M-HALT ! ;

DOC" M-STEP ( -- ) fetch and execute one 1130 instruction"
: M-STEP ( -- )
    M-IAR @ M-PC !
    M-PC @ M@ M-IR !
    1 M-IAR+
    M-PC @ M-IR @ M-REMEMBER
    M-IR @ 0= IF
        M-PC @ S" executed zero at " M-STOPH
        EXIT
    THEN
    M-IR @ 11 RSHIFT 31 AND
    M-IR @ 8 RSHIFT 3 AND M-TAG !
    DUP M-FBIT + C@ 0<> M-IR @ 1024 AND 0<> AND M-LONG !
    M-LONG @ IF
        M-IAR @ M@ M-W2 !
        1 M-IAR+
    THEN
    CASE
        1 OF M-XIO ENDOF
        2 OF M-SHL ENDOF
        3 OF M-SHR ENDOF
        4 OF
            M-IR @ 1 AND 0<> M-OVF !
            M-IR @ 2 AND 0<> M-CARRY !
        ENDOF
        5 OF
            M-EA DUP M@ 65280 AND
            M-CARRY @ IF 2 OR THEN
            M-OVF @ IF 1 OR THEN
            SWAP M!
            0 M-CARRY ! 0 M-OVF !
        ENDOF
        6 OF M-WAIT ENDOF
        8 OF
            M-LONG @ IF M-COND ELSE FALSE THEN 0= IF
                M-EA DUP M-IAR @ SWAP M!
                1+ 32767 AND M-IAR !
            THEN
        ENDOF
        9 OF
            M-LONG @ IF
                M-COND 0= IF M-EA 32767 AND M-IAR ! THEN
            ELSE
                M-COND IF 1 M-IAR+ THEN
            THEN
        ENDOF
        12 OF M-LDX ENDOF
        13 OF M-STX ENDOF
        14 OF M-MDX ENDOF
        16 OF M-EA M@ M-ADD ENDOF
        17 OF M-EA M-DADD ENDOF
        18 OF M-EA M@ M-SUB ENDOF
        19 OF M-EA M-DSUB ENDOF
        20 OF M-EA M@ M-MUL ENDOF
        21 OF M-EA M@ M-DIV ENDOF
        24 OF M-EA M@ M-ACC ! ENDOF
        25 OF
            M-EA DUP M@ M-ACC ! 1 OR M@ M-EXT !
        ENDOF
        26 OF M-EA M-ACC @ SWAP M! ENDOF
        27 OF
            M-EA DUP 1 OR M-EXT @ SWAP M!
            M-ACC @ SWAP M!
        ENDOF
        28 OF M-EA M@ M-ACC @ AND M-ACC ! ENDOF
        29 OF M-EA M@ M-ACC @ OR M-ACC ! ENDOF
        30 OF M-EA M@ M-ACC @ XOR M-ACC ! ENDOF
        M-BAD
    ENDCASE
    M-ACC @ 65535 AND M-ACC !
    M-EXT @ 65535 AND M-EXT !
    A-ACCEPT @ M-PC @ = IF M-NOTE THEN ;

DOC" M-SERVICE ( kind -- ) trap LIBF: disk read, printer, or an unknown call"
: M-SERVICE ( kind -- )
    M-IAR @ 1+ M@
    OVER 1 = OVER 4096 = AND IF
        2DROP
        M-IAR @ 2 + M@ M-READ
        4 M-IAR+
        EXIT
    THEN
    OVER 1 = OVER 0= AND IF
        2DROP
        4 M-IAR+
        EXIT
    THEN
    OVER 2 = OVER 8192 = AND IF
        2DROP
        M-IAR @ 2 + M@ M-PRINT
        4 M-IAR+
        EXIT
    THEN
    OVER 2 = OVER 0= AND IF
        2DROP
        3 M-IAR+
        EXIT
    THEN
    2DROP
    M-IAR @ S" LIBF " M-STOPH ;

DOC" M-UNIQ ( -- n ) how many distinct recent addresses are in the ring"
: M-UNIQ ( -- n )
    0
    48 0 DO
        I CELLS M-RING + @
        DUP 0< IF DROP ELSE
            0 I 0 ?DO
                OVER I CELLS M-RING + @ = IF 1+ THEN
            LOOP
            SWAP DROP 0= IF 1+ THEN
        THEN
    LOOP ;

DOC" M-HOT? ( -- flag ) true when the same few addresses repeat"
: M-HOT? ( -- flag )
    M-UNIQ DUP 1 7 WITHIN IF
        DROP 1 M-HOT +!
    ELSE
        DROP 0 M-HOT !
    THEN
    M-HOT @ 40 >= ;

DOC" M-RUN ( limit -- ) step until halt or a stuck loop. limit is stored, not checked"
: M-RUN ( limit -- )
    M-LIM !
    BEGIN
        M-HALT @ 0=
\        M-STEPS @ M-LIM @ < AND    \ limit runtime is disabled for now
    WHILE
        1 M-STEPS +!
        M-IAR @ A-LINK @ = IF
            S" returned to monitor" M-STOP
        ELSE
            M-IAR @ A-LIB? IF M-SERVICE ELSE M-STEP THEN
        THEN
        M-HALT @ 0= M-STEPS @ 20000 MOD 0= AND IF
            M-HOT? IF M-IAR @ S" stuck near " M-STOPH THEN
        THEN
    REPEAT
    M-HALT @ 0= IF S" step limit" M-STOP THEN
    M-FLUSH ;

DOC" M-BOOT ( a u -- ) load the image, reset the 1130, and pack deck a u"
: M-BOOT ( a u -- )
    M-ABC
    A-IMAGE M-MEM M-MEMN CELLS MOVE
    A-ENTRY @ M-IAR !
    0 M-ACC ! 0 M-EXT ! 0 M-CARRY ! 0 M-OVF !
    0 M-HALT ! 0 M-HI ! 0 M-STEPS !
    0 M-KBUSY ! 0 M-PDONE ! 0 M-KEYF !
    0 M-XN ! 0 M-TAT ! 0 M-RAT ! 0 M-HOT !
    0 M-CLEN ! 0 M-LLEN ! 0 M-ACCN ! 0 M-ACOL !
    0 M-NSLOT ! 0 M-NREAD ! 0 M-KN ! 0 M-KR !
    0 M-WHY C!
    48 0 DO -1 I CELLS M-RING + ! LOOP
    S" A" A-SYM IF M-WS ! ELSE 0 M-WS ! THEN
    M-PACK ;

DOC" M-TRACE ( -- ) print the XIO log, recent instructions, and console text"
: M-TRACE ( -- )
    M-XN @ 0 ?DO
        I 5 * CELLS M-XLOG +
        ." XIO dev " DUP @ .H4
        ."  fn " DUP CELL+ @ .
        ."  mod " DUP 2 CELLS + @ .H4
        ."  addr " DUP 3 CELLS + @ .H4
        ."  at " 4 CELLS + @ .H4 CR
    LOOP
    ." last instructions:" CR
    24 0 DO
        M-TAT @ I + 24 MOD 2 * CELLS M-TRAIL +
        DUP @ OVER CELL+ @ OR IF
            DUP @ .H4 SPACE CELL+ @ .H4 CR
        ELSE DROP THEN
    LOOP
    ." low memory:" CR
    32 0 DO
        I 8 MOD 0= IF CR I .H4 SPACE THEN
        I M@ .H4 SPACE
    LOOP CR
    M-CLEN @ IF ." console: " M-CON M-CLEN @ TYPE CR THEN
    M-ACCN @ IF ." accepted: " M-ACCBUF M-ACCN @ 240 M-MIN TYPE CR THEN
    ." steps " M-STEPS @ . ." sectors " M-NREAD @ . CR ;

DOC" M-WHY. ( -- ) print the halt reason"
: M-WHY. ( -- ) M-WHY COUNT TYPE ;
