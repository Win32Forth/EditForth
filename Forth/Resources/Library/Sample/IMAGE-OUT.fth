\ image-out.fth — write a PNG and a baseline JPEG from an RGB8 buffer.
\ save-png ( pix w h c-addr u -- ior )
\ save-jpg ( pix w h c-addr u -- ior )
\ PNG is exact (stored-block zlib). JPEG is 4:4:4 quality 85.
\ No Python and no sips.

[UNDEFINED] save-png [IF] 

push-orders 
only forth also definitions

vocabulary imagesave
imagesave also definitions

create io-cos
    5793 , 5793 , 5793 , 5793 , 5793 , 5793 , 5793 , 5793 ,
    8035 , 6811 , 4551 , 1598 , -1598 , -4551 , -6811 , -8035 ,
    7568 , 3135 , -3135 , -7568 , -7568 , -3135 , 3135 , 7568 ,
    6811 , -1598 , -8035 , -4551 , 4551 , 8035 , 1598 , -6811 ,
    5793 , -5793 , -5793 , 5793 , 5793 , -5793 , -5793 , 5793 ,
    4551 , -8035 , 1598 , 6811 , -6811 , -1598 , 8035 , -4551 ,
    3135 , -7568 , 7568 , -3135 , -3135 , 7568 , -7568 , 3135 ,
    1598 , -4551 , 6811 , -8035 , 8035 , -6811 , 4551 , -1598 ,

create io-qy
    5 , 3 , 3 , 5 , 7 , 12 , 15 , 18 ,
    4 , 4 , 4 , 6 , 8 , 17 , 18 , 17 ,
    4 , 4 , 5 , 7 , 12 , 17 , 21 , 17 ,
    4 , 5 , 7 , 9 , 15 , 26 , 24 , 19 ,
    5 , 7 , 11 , 17 , 20 , 33 , 31 , 23 ,
    7 , 11 , 17 , 19 , 24 , 31 , 34 , 28 ,
    15 , 19 , 23 , 26 , 31 , 36 , 36 , 30 ,
    22 , 28 , 29 , 29 , 34 , 30 , 31 , 30 ,

create io-qc
    5 , 5 , 7 , 14 , 30 , 30 , 30 , 30 ,
    5 , 6 , 8 , 20 , 30 , 30 , 30 , 30 ,
    7 , 8 , 17 , 30 , 30 , 30 , 30 , 30 ,
    14 , 20 , 30 , 30 , 30 , 30 , 30 , 30 ,
    30 , 30 , 30 , 30 , 30 , 30 , 30 , 30 ,
    30 , 30 , 30 , 30 , 30 , 30 , 30 , 30 ,
    30 , 30 , 30 , 30 , 30 , 30 , 30 , 30 ,
    30 , 30 , 30 , 30 , 30 , 30 , 30 , 30 ,

create io-zig
    0 , 1 , 8 , 16 , 9 , 2 , 3 , 10 ,
    17 , 24 , 32 , 25 , 18 , 11 , 4 , 5 ,
    12 , 19 , 26 , 33 , 40 , 48 , 41 , 34 ,
    27 , 20 , 13 , 6 , 7 , 14 , 21 , 28 ,
    35 , 42 , 49 , 56 , 57 , 50 , 43 , 36 ,
    29 , 22 , 15 , 23 , 30 , 37 , 44 , 51 ,
    58 , 59 , 52 , 45 , 38 , 31 , 39 , 46 ,
    53 , 60 , 61 , 54 , 47 , 55 , 62 , 63 ,

create io-dcl-bits
    $00 c, $01 c, $05 c, $01 c, $01 c, $01 c, $01 c, $01 c, $01 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c,

create io-dcc-bits
    $00 c, $03 c, $01 c, $01 c, $01 c, $01 c, $01 c, $01 c, $01 c, $01 c, $01 c, $00 c, $00 c, $00 c, $00 c, $00 c,

create io-dc-val
    $00 c, $01 c, $02 c, $03 c, $04 c, $05 c, $06 c, $07 c, $08 c, $09 c, $0A c, $0B c,

create io-acl-bits
    $00 c, $02 c, $01 c, $03 c, $03 c, $02 c, $04 c, $03 c, $05 c, $05 c, $04 c, $04 c, $00 c, $00 c, $01 c, $7D c,

create io-acc-bits
    $00 c, $02 c, $01 c, $02 c, $04 c, $04 c, $03 c, $04 c, $07 c, $05 c, $04 c, $04 c, $00 c, $01 c, $02 c, $77 c,

create io-acl-val
    $01 c, $02 c, $03 c, $00 c, $04 c, $11 c, $05 c, $12 c, $21 c, $31 c, $41 c, $06 c, $13 c, $51 c, $61 c, $07 c,
    $22 c, $71 c, $14 c, $32 c, $81 c, $91 c, $A1 c, $08 c, $23 c, $42 c, $B1 c, $C1 c, $15 c, $52 c, $D1 c, $F0 c,
    $24 c, $33 c, $62 c, $72 c, $82 c, $09 c, $0A c, $16 c, $17 c, $18 c, $19 c, $1A c, $25 c, $26 c, $27 c, $28 c,
    $29 c, $2A c, $34 c, $35 c, $36 c, $37 c, $38 c, $39 c, $3A c, $43 c, $44 c, $45 c, $46 c, $47 c, $48 c, $49 c,
    $4A c, $53 c, $54 c, $55 c, $56 c, $57 c, $58 c, $59 c, $5A c, $63 c, $64 c, $65 c, $66 c, $67 c, $68 c, $69 c,
    $6A c, $73 c, $74 c, $75 c, $76 c, $77 c, $78 c, $79 c, $7A c, $83 c, $84 c, $85 c, $86 c, $87 c, $88 c, $89 c,
    $8A c, $92 c, $93 c, $94 c, $95 c, $96 c, $97 c, $98 c, $99 c, $9A c, $A2 c, $A3 c, $A4 c, $A5 c, $A6 c, $A7 c,
    $A8 c, $A9 c, $AA c, $B2 c, $B3 c, $B4 c, $B5 c, $B6 c, $B7 c, $B8 c, $B9 c, $BA c, $C2 c, $C3 c, $C4 c, $C5 c,
    $C6 c, $C7 c, $C8 c, $C9 c, $CA c, $D2 c, $D3 c, $D4 c, $D5 c, $D6 c, $D7 c, $D8 c, $D9 c, $DA c, $E1 c, $E2 c,
    $E3 c, $E4 c, $E5 c, $E6 c, $E7 c, $E8 c, $E9 c, $EA c, $F1 c, $F2 c, $F3 c, $F4 c, $F5 c, $F6 c, $F7 c, $F8 c,
    $F9 c, $FA c,

create io-acc-val
    $00 c, $01 c, $02 c, $03 c, $11 c, $04 c, $05 c, $21 c, $31 c, $06 c, $12 c, $41 c, $51 c, $07 c, $61 c, $71 c,
    $13 c, $22 c, $32 c, $81 c, $08 c, $14 c, $42 c, $91 c, $A1 c, $B1 c, $C1 c, $09 c, $23 c, $33 c, $52 c, $F0 c,
    $15 c, $62 c, $72 c, $D1 c, $0A c, $16 c, $24 c, $34 c, $E1 c, $25 c, $F1 c, $17 c, $18 c, $19 c, $1A c, $26 c,
    $27 c, $28 c, $29 c, $2A c, $35 c, $36 c, $37 c, $38 c, $39 c, $3A c, $43 c, $44 c, $45 c, $46 c, $47 c, $48 c,
    $49 c, $4A c, $53 c, $54 c, $55 c, $56 c, $57 c, $58 c, $59 c, $5A c, $63 c, $64 c, $65 c, $66 c, $67 c, $68 c,
    $69 c, $6A c, $73 c, $74 c, $75 c, $76 c, $77 c, $78 c, $79 c, $7A c, $82 c, $83 c, $84 c, $85 c, $86 c, $87 c,
    $88 c, $89 c, $8A c, $92 c, $93 c, $94 c, $95 c, $96 c, $97 c, $98 c, $99 c, $9A c, $A2 c, $A3 c, $A4 c, $A5 c,
    $A6 c, $A7 c, $A8 c, $A9 c, $AA c, $B2 c, $B3 c, $B4 c, $B5 c, $B6 c, $B7 c, $B8 c, $B9 c, $BA c, $C2 c, $C3 c,
    $C4 c, $C5 c, $C6 c, $C7 c, $C8 c, $C9 c, $CA c, $D2 c, $D3 c, $D4 c, $D5 c, $D6 c, $D7 c, $D8 c, $D9 c, $DA c,
    $E2 c, $E3 c, $E4 c, $E5 c, $E6 c, $E7 c, $E8 c, $E9 c, $EA c, $F2 c, $F3 c, $F4 c, $F5 c, $F6 c, $F7 c, $F8 c,
    $F9 c, $FA c,

create io-ys       64 cells allot
create io-cbs      64 cells allot
create io-crs      64 cells allot
create io-tmp      64 cells allot
create io-blk      64 cells allot
create io-dcl-code 256 cells allot
create io-dcl-len  256 cells allot
create io-dcc-code 256 cells allot
create io-dcc-len  256 cells allot
create io-acl-code 256 cells allot
create io-acl-len  256 cells allot
create io-acc-code 256 cells allot
create io-acc-len  256 cells allot

variable io-ypred
variable io-cbpred
variable io-crpred

0 value io-pix
0 value io-iw
0 value io-ih
0 value io-path
0 value io-pathn
0 value io-buf
0 value io-op
0 value io-max
0 value io-filt
0 value io-fn
0 value io-mark
0 value io-ada
0 value io-adb
0 value io-crcv
0 value io-ready
0 value io-bitsa
0 value io-val
0 value io-code
0 value io-len
0 value io-vi
0 value io-hcode
0 value io-acc
0 value io-bn
0 value io-sb
0 value io-db
0 value io-sy
0 value io-su
0 value io-mx
0 value io-my
0 value io-pr
0 value io-pg
0 value io-pb
0 value io-run
0 value io-dcc
0 value io-dcl
0 value io-accodes
0 value io-aclens

: io-oc, ( c -- )
    io-op io-max >= if 1 throw then
    io-buf io-op + c!
    io-op 1+ to io-op ;

: io-ec, ( c -- )
    dup io-oc,
    255 = if 0 io-oc, then ;

: io-o2le ( u -- )
    dup 255 and io-oc,
    8 rshift 255 and io-oc, ;

: io-o2be ( u -- )
    dup 8 rshift 255 and io-oc,
    255 and io-oc, ;

: io-o4be ( u -- )
    dup 24 rshift 255 and io-oc,
    dup 16 rshift 255 and io-oc,
    dup 8 rshift 255 and io-oc,
    255 and io-oc, ;

: io-move ( a u -- )
    0 ?do dup i + c@ io-oc, loop drop ;

: io-poke4 ( u a -- )
    swap >r
    r@ 24 rshift 255 and over c!
    r@ 16 rshift 255 and over 1+ c!
    r@ 8 rshift 255 and over 2 + c!
    r> 255 and swap 3 + c! ;

: io-crc-byte ( c -- )
    io-crcv xor
    8 0 do
        dup 1 and if
            1 rshift 3988292384 xor
        else
            1 rshift
        then
        4294967295 and
    loop
    to io-crcv ;

: io-crc ( a u -- crc )
    4294967295 to io-crcv
    0 ?do dup i + c@ io-crc-byte loop drop
    io-crcv 4294967295 xor ;

: io-chunk-start ( -- )
    io-buf io-op + to io-mark
    0 io-o4be ;

: io-chunk-end ( -- )
    io-buf io-op + io-mark - 4 -
    dup 4 - io-mark io-poke4
    io-mark 4 + swap io-crc io-o4be ;

: io-adler ( c -- )
    io-ada + 65521 mod to io-ada
    io-adb io-ada + 65521 mod to io-adb ;

: io-astore ( c a -- a+1 )
    tuck c!
    dup c@ io-adler
    1+ ;

: io-filter ( dest -- )
    1 to io-ada
    0 to io-adb
    io-ih 0 do
        0 swap io-astore
        io-iw 3 * 0 do
            io-pix j io-iw * 3 * i + + c@
            swap io-astore
        loop
    loop
    drop ;

: io-stored ( a u -- )
    120 io-oc,
    1 io-oc,
    begin dup while
        dup 65535 > if 65535 else dup then
        >r
        dup r@ = if 1 else 0 then io-oc,
        r@ io-o2le
        r@ 65535 xor io-o2le
        over r@ io-move
        swap r@ + swap
        r> -
    repeat
    2drop
    io-adb 16 lshift io-ada or io-o4be ;

: io-png-bytes ( -- )
    137 io-oc, 80 io-oc, 78 io-oc, 71 io-oc,
    13 io-oc, 10 io-oc, 26 io-oc, 10 io-oc,
    io-chunk-start
    s" IHDR" io-move
    io-iw io-o4be
    io-ih io-o4be
    8 io-oc, 2 io-oc, 0 io-oc, 0 io-oc, 0 io-oc,
    io-chunk-end
    io-chunk-start
    s" IDAT" io-move
    io-filt io-fn io-stored
    io-chunk-end
    io-chunk-start
    s" IEND" io-move
    io-chunk-end ;

: io-flush ( -- ior )
    io-path io-pathn w/o bin create-file
    ?dup if nip exit then
    >r
    io-buf io-op r@ write-file
    r> close-file or ;

\ start of primities for save-jpg

: io-bits ( code len -- )
    dup 0= if 2drop exit then
    tuck
    io-acc swap lshift or
    swap io-bn +
    tuck
    1 swap lshift 1- and
    swap
    begin dup 8 >= while
        8 -
        2dup rshift 255 and io-ec,
        tuck
        1 swap lshift 1- and
        swap
    repeat
    to io-bn
    to io-acc ;

: io-pad ( -- )
    io-bn 0= if exit then
    8 io-bn -
    dup 1 swap lshift 1- swap io-bits ;

: io-huff ( bits vals codes lens -- )
    to io-len to io-code to io-val to io-bitsa
    256 0 do 0 i cells io-len + ! loop
    0 to io-vi
    0 to io-hcode
    16 0 do
        io-bitsa i + c@ 0 ?do
            io-val io-vi + c@
            io-hcode over cells io-code + !
            j 1+ over cells io-len + !
            drop
            io-vi 1+ to io-vi
            io-hcode 1+ to io-hcode
        loop
        io-hcode 1 lshift to io-hcode
    loop ;

: io-init ( -- )
    io-ready if exit then
    io-dcl-bits io-dc-val io-dcl-code io-dcl-len io-huff
    io-dcc-bits io-dc-val io-dcc-code io-dcc-len io-huff
    io-acl-bits io-acl-val io-acl-code io-acl-len io-huff
    io-acc-bits io-acc-val io-acc-code io-acc-len io-huff
    1 to io-ready ;

: io-dct-rows ( src dest -- )
    to io-db to io-sb
    8 0 do
        i to io-sy
        8 0 do
            i to io-su
            0
            8 0 do
                io-sb io-sy 8 * i + cells + @
                io-cos io-su 8 * i + cells + @
                * +
            loop
            io-db io-sy 8 * io-su + cells + !
        loop
    loop ;

: io-ddiv ( n -- n )
    dup 0< if
        negate 134217728 + 268435456 / negate
    else
        134217728 + 268435456 /
    then ;

: io-dct-cols ( src dest -- )
    to io-db to io-sb
    8 0 do
        i to io-su
        8 0 do
            i to io-sy
            0
            8 0 do
                io-sb i 8 * io-su + cells + @
                io-cos io-sy 8 * i + cells + @
                * +
            loop
            io-ddiv
            io-db io-sy 8 * io-su + cells + !
        loop
    loop ;

: io-qround ( n q -- n )
    >r
    dup 0< if
        negate r@ 2/ + r> / negate
    else
        r@ 2/ + r> /
    then ;

: io-clip ( n -- n )
    dup 2047 > if drop 2047 exit then
    dup -2047 < if drop -2047 then ;

: io-dctq ( src q -- )
    swap io-tmp io-dct-rows
    io-tmp io-blk io-dct-cols
    64 0 do
        io-blk i cells + @
        over i cells + @
        io-qround io-clip
        io-blk i cells + !
    loop
    drop ;

: io-clip8 ( n -- n )
    dup 127 > if drop 127 exit then
    dup -128 < if drop -128 then ;

: io-y ( r g b -- n )
    >r >r
    19595 *
    r> 38470 * +
    r> 7471 * +
    32768 + 65536 / 128 - io-clip8 ;

: io-cb ( r g b -- n )
    >r >r
    11059 *
    r> 21709 * +
    negate
    r> 32768 * +
    8388608 + 32768 + 65536 / 128 - io-clip8 ;

: io-cr ( r g b -- n )
    >r >r
    32768 *
    r> 27439 * -
    r> 5329 * -
    8388608 + 32768 + 65536 / 128 - io-clip8 ;

: io-pix@ ( x y -- r g b )
    0 max io-ih 1- min
    swap 0 max io-iw 1- min
    swap
    io-iw * + 3 * io-pix +
    dup c@ over 1+ c@ rot 2 + c@ ;

: io-grab ( mx my -- )
    to io-my to io-mx
    8 0 do
        8 0 do
            io-mx i + io-my j + io-pix@
            to io-pb to io-pg to io-pr
            io-pr io-pg io-pb io-y
            j 8 * i + cells io-ys + !
            io-pr io-pg io-pb io-cb
            j 8 * i + cells io-cbs + !
            io-pr io-pg io-pb io-cr
            j 8 * i + cells io-crs + !
        loop
    loop ;

: io-cat ( n -- cat )
    abs 0
    begin over 0> while
        swap 1 rshift swap 1+
    repeat
    nip ;

: io-sym ( sym codes lens -- )
    to io-pg
    to io-pr
    dup cells io-pr + @
    swap cells io-pg + @
    io-bits ;

: io-extra ( n cat -- )
    dup 0= if 2drop exit then
    over 0< if swap 1- swap then
    tuck
    1 swap lshift 1- and
    swap io-bits ;

: io-dc ( diff -- )
    dup io-cat to io-pb
    io-pb io-dcc io-dcl io-sym
    io-pb io-extra ;

: io-ac ( -- )
    0 to io-run
    64 1 do
        i cells io-zig + @ cells io-blk + @
        dup 0= if
            drop io-run 1+ to io-run
        else
            begin io-run 15 > while
                240 io-accodes io-aclens io-sym
                io-run 16 - to io-run
            repeat
            dup io-cat to io-pb
            io-run 4 lshift io-pb or
            io-accodes io-aclens io-sym
            io-pb io-extra
            0 to io-run
        then
    loop
    io-run if 0 io-accodes io-aclens io-sym then ;

: io-comp ( src q pred -- )
    to io-my
    io-dctq
    io-my @ io-blk @ swap - io-dc
    io-blk @ io-my !
    io-ac ;

: io-scan ( -- )
    0 io-ypred !
    0 io-cbpred !
    0 io-crpred !
    0 to io-acc
    0 to io-bn
    io-ih 7 + 8 / 0 do
        io-iw 7 + 8 / 0 do
            i 8 * j 8 * io-grab
            io-dcl-code to io-dcc
            io-dcl-len to io-dcl
            io-acl-code to io-accodes
            io-acl-len to io-aclens
            io-ys io-qy io-ypred io-comp
            io-dcc-code to io-dcc
            io-dcc-len to io-dcl
            io-acc-code to io-accodes
            io-acc-len to io-aclens
            io-cbs io-qc io-cbpred io-comp
            io-crs io-qc io-crpred io-comp
        loop
    loop
    io-pad ;

: io-dqt ( q id -- )
    io-oc,
    64 0 do
        i cells io-zig + @ cells over + @ io-oc,
    loop
    drop ;

: io-dht1 ( bits vals n id -- )
    io-oc,
    >r
    swap
    16 0 do dup i + c@ io-oc, loop drop
    r> 0 do dup i + c@ io-oc, loop drop ;

: io-jpg-bytes ( -- )
    255 io-oc, 216 io-oc,
    255 io-oc, 224 io-oc,
    16 io-o2be
    s" JFIF" io-move
    0 io-oc,
    1 io-oc, 1 io-oc, 0 io-oc,
    0 io-oc, 1 io-oc,
    0 io-oc, 1 io-oc,
    0 io-oc, 0 io-oc,
    255 io-oc, 219 io-oc,
    132 io-o2be
    io-qy 0 io-dqt
    io-qc 1 io-dqt
    255 io-oc, 192 io-oc,
    17 io-o2be
    8 io-oc,
    io-ih io-o2be
    io-iw io-o2be
    3 io-oc,
    1 io-oc, 17 io-oc, 0 io-oc,
    2 io-oc, 17 io-oc, 1 io-oc,
    3 io-oc, 17 io-oc, 1 io-oc,
    255 io-oc, 196 io-oc,
    418 io-o2be
    io-dcl-bits io-dc-val 12 0 io-dht1
    io-dcc-bits io-dc-val 12 1 io-dht1
    io-acl-bits io-acl-val 162 16 io-dht1
    io-acc-bits io-acc-val 162 17 io-dht1
    255 io-oc, 218 io-oc,
    12 io-o2be
    3 io-oc,
    1 io-oc, 0 io-oc,
    2 io-oc, 17 io-oc,
    3 io-oc, 17 io-oc,
    0 io-oc, 63 io-oc, 0 io-oc,
    io-scan
    255 io-oc, 217 io-oc, ;

forth definitions

: save-png ( pix w h c-addr u -- ior )
    to io-pathn to io-path
    to io-ih to io-iw to io-pix
    io-ih io-iw 3 * 1+ * to io-fn
    io-fn allocate ?dup if nip exit then to io-filt
    io-fn 4096 + dup to io-max
    allocate ?dup if io-filt free drop nip exit then to io-buf
    0 to io-op
    io-filt io-filter
    io-png-bytes
    io-flush
    io-buf free drop
    io-filt free drop ;

: save-jpg ( pix w h c-addr u -- ior )
    to io-pathn to io-path
    to io-ih to io-iw to io-pix
    io-init
    io-ih 7 + 8 / io-iw 7 + 8 / * 1200 * 8192 +
    dup to io-max
    allocate ?dup if nip exit then to io-buf
    0 to io-op
    io-jpg-bytes
    io-flush
    io-buf free drop ;

pop-orders

[THEN]

