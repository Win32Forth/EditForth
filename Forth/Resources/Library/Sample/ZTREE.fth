\ ZTREE.fth — sum of file sizes by directory
\
\ Port of TCOM ZTREE.FTH (Tom Zimmer, public domain). The DOS program walked
\ a disk and could delete a whole tree. This copy only lists sizes. It does
\ not delete your files. It asks for a directory and a name spec, then runs
\ find through the host shell. That is an EditForth console program. The
\ browser build has no shell, so ZTREE there only explains itself.
\
\ Load:
\   FROMLIB FLOAD Sample/ZTREE.fth
\   ZTREE
\
\ An empty directory means the current directory. An empty spec means every
\ file. The spec may contain * and ?. Esc stops the report early.
\
\ Public domain.

[DEFINED] ANEW [IF] ANEW ZTREE_MODULE [THEN]

ONLY FORTH DEFINITIONS
DECIMAL

[DEFINED] SYSTEM [IF]

: ZTREE-CREDIT ( -- )
  CR ." ZTREE sums file sizes under a directory."
  CR ." It does not delete files." CR
  ;

CREATE ZT-DIR 200 ALLOT
VARIABLE ZT-DLEN
CREATE ZT-SPEC 80 ALLOT
VARIABLE ZT-SLEN
CREATE ZT-ASK 16 ALLOT
CREATE ZT-CMD 480 ALLOT
VARIABLE ZT-N
CREATE ZT-LINE 512 ALLOT
VARIABLE ZT-LL
CREATE ZT-CUR 300 ALLOT
VARIABLE ZT-CLEN
VARIABLE ZT-IN
VARIABLE ZT-LIST
VARIABLE ZT-LO
VARIABLE ZT-HI
VARIABLE ZT-DLO
VARIABLE ZT-DHI
VARIABLE ZT-CNT
VARIABLE ZT-DCNT
VARIABLE ZT-STOP

: ZT-CH ( c -- flag )
  DUP 47 = OVER 46 = OR OVER 45 = OR OVER 95 = OR
  OVER 42 = OR OVER 63 = OR
  OVER 48 58 WITHIN OR
  OVER 65 91 WITHIN OR
  SWAP 97 123 WITHIN OR ;

: ZT-OK ( c-addr u -- flag )
  DUP 240 > IF 2DROP FALSE EXIT THEN
  0 DO
    DUP I + C@ ZT-CH 0= IF DROP UNLOOP FALSE EXIT THEN
  LOOP
  DROP TRUE ;

: ZT. ( u -- )
  0 <# #S #> TYPE SPACE ;

\ ( lo1 hi1 lo2 hi2 -- lo hi )  no carry out of a 64-bit low cell
: ZT-D+ ( lo1 hi1 lo2 hi2 -- lo hi )
  SWAP >R
  +
  SWAP R> +
  SWAP ;

: ZT+ ( c-addr u -- )
  DUP ZT-N @ + 460 > IF 2DROP EXIT THEN
  DUP >R
  ZT-CMD ZT-N @ + SWAP CMOVE
  R> ZT-N +! ;

: ZT-BUILD ( c-addr u c-addr2 u2 -- )
  0 ZT-N !
  S" find " ZT+
  2SWAP
  DUP 0= IF 2DROP S" ." ZT+ ELSE ZT+ THEN
  S"  -type f " ZT+
  DUP 0= IF
    2DROP
  ELSE
    S" -name '" ZT+
    ZT+
    S" ' " ZT+
  THEN
  S" -print | sort > /tmp/editforth-ztree.lst" ZT+
  ;

: ZT-DIRNAME ( c-addr u -- c-addr u2 )
  BEGIN
    DUP 0= IF EXIT THEN
    1- 2DUP + C@ 47 = IF EXIT THEN
  AGAIN ;

: ZT-SHOW ( -- )
  ZT-DCNT @ 0= IF EXIT THEN
  CR ZT-CUR ZT-CLEN @ TYPE
  ."   " ZT-DCNT @ ZT. ." files  " ZT-DLO @ ZT.
  ZT-DHI @ IF ZT-DHI @ ZT. THEN
  ." bytes"
  ZT-LO @ ZT-HI @ ZT-DLO @ ZT-DHI @ ZT-D+
  ZT-HI ! ZT-LO !
  ZT-DCNT @ ZT-CNT +!
  0 ZT-DCNT !  0 ZT-DLO !  0 ZT-DHI !
  ;

: ZT-SETDIR ( c-addr u -- )
  2DUP ZT-CUR ZT-CLEN @ COMPARE 0= IF 2DROP EXIT THEN
  ZT-SHOW
  240 MIN DUP ZT-CLEN !
  ZT-CUR SWAP CMOVE
  ;

: ZT-SIZE ( c-addr u -- u )
  R/O BIN OPEN-FILE IF DROP 2DROP 0 EXIT THEN
  >R
  R@ FILE-SIZE IF 2DROP R> CLOSE-FILE DROP 0 EXIT THEN
  DROP
  R> CLOSE-FILE DROP
  ;

: ZT-ONE ( c-addr u -- )
  2DUP ZT-DIRNAME ZT-SETDIR
  ZT-LIST @ IF CR ."    " 2DUP TYPE THEN
  ZT-SIZE
  0 ZT-DLO @ ZT-DHI @ ZT-D+
  ZT-DHI ! ZT-DLO !
  1 ZT-DCNT +!
  ;

: ZT-READ ( -- )
  S" /tmp/editforth-ztree.lst" R/O OPEN-FILE IF
    DROP CR ." Could not read the file list." CR EXIT
  THEN
  ZT-IN !
  BEGIN
    ZT-STOP @ 0=
  WHILE
    ZT-LINE 500 ZT-IN @ READ-LINE
    ?DUP IF DROP 2DROP -1 ZT-STOP !
    ELSE
      0= IF DROP -1 ZT-STOP !
      ELSE
        ZT-LINE SWAP ZT-ONE
        KEY? IF KEY 27 = IF -1 ZT-STOP ! THEN THEN
      THEN
    THEN
  REPEAT
  ZT-IN @ CLOSE-FILE DROP
  ZT-SHOW
  CR CR ." TOTAL  " ZT-CNT @ ZT. ." files  " ZT-LO @ ZT.
  ZT-HI @ IF ZT-HI @ ZT. THEN
  ." bytes" CR
  ;

: ZTREE ( -- )
  ZTREE-CREDIT
  CR ." Directory (empty = current): "
  ZT-DIR 180 ACCEPT
  DUP ZT-DLEN !
  ZT-DIR SWAP ZT-OK 0= IF
    CR ." That directory has a character ZTREE will not pass to the shell." CR
    EXIT
  THEN
  CR ." Name spec (empty = all, * and ? allowed): "
  ZT-SPEC 60 ACCEPT
  DUP ZT-SLEN !
  ZT-SPEC SWAP ZT-OK 0= IF
    CR ." That spec has a character ZTREE will not pass to the shell." CR
    EXIT
  THEN
  CR ." List each file? "
  ZT-ASK 8 ACCEPT
  DUP IF ZT-ASK C@ 32 OR 121 = ELSE DROP FALSE THEN
  ZT-LIST !
  0 ZT-LO !  0 ZT-HI !  0 ZT-DLO !  0 ZT-DHI !
  0 ZT-CNT !  0 ZT-DCNT !  0 ZT-CLEN !  0 ZT-STOP !
  ZT-DIR ZT-DLEN @ ZT-SPEC ZT-SLEN @ ZT-BUILD
  ZT-CMD ZT-N @ SYSTEM 0< IF
    CR ." The shell is not available." CR EXIT
  THEN
  ZT-READ
  S" /tmp/editforth-ztree.lst" DELETE-FILE DROP
  ;

[ELSE]

: ZTREE ( -- )
  CR ." ZTREE sums directories on the EditForth console."
  CR ." This browser Forth has no shell, so there is nothing to run." CR
  ;

[THEN]

CR .( Run: ZTREE ) CR
