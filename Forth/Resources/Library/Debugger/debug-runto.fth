\ debug-runto.fth — Run to Here: UTF-8 offset → threaded cell IP
\ Loaded from debugger.fth after dbg-map.fth (needs DBG-MAP-* / DBG-CFA@).
\ Editor-only path: host sets RUNTO-OFF via kernel_debug_runto_request, then
\ pushes key 135; DBG-PAUSE-UI calls DBG-RUNTO-DO → (RUNTO-IP) + keep-armed GO.
\
\ Search order: SYSVOC (DBG-CFA@ / (RUNTO-IP) / …) + DEBUGGER (DBG-MAP-*).
\
\ Resolve searches the paused CFA first, then other mapped colon bodies in the
\ same VIEW file (so Run to drop in MAINX works while paused in MAIN).

ONLY FORTH ALSO SYSVOC ALSO DEBUGGER DEFINITIONS

\ Find first map cell whose span contains target UTF-8 file offset. -1 if none.
: DBG-MAP-FIND-OFF  ( cmap target -- cell#|-1 )
  {: cmap target | n cell# off len -- :}
  cmap 0= IF  -1 EXIT  THEN
  cmap DBG-CMAP-NCELLS@ TO n
  0 TO cell#
  BEGIN  cell# n < WHILE
     cmap cell# DBG-SLOT-LEN@ TO len
     len IF
        cmap cell# DBG-SLOT-OFF@ TO off
        target off >=
        target off len + < AND IF
           cell# EXIT
        THEN
     THEN
     cell# 1+ TO cell#
  REPEAT
  -1 ;

\ Scan every cmap already built for this file section.
: DBG-RUNTO-SCAN-CMAPS  ( fsec target -- cmap cell# | 0 -1 )
  {: fsec target | cmap cell# next -- :}
  0 TO cmap
  -1 TO cell#
  fsec 0= IF  0 -1 EXIT  THEN
  fsec 2 CELLS + @ TO next
  BEGIN  next  cell# 0< AND  WHILE
     next TO cmap
     cmap target DBG-MAP-FIND-OFF TO cell#
     cell# 0< IF
        cmap @ TO next
     THEN
  REPEAT
  cell# 0< IF  0 -1  ELSE  cmap cell#  THEN ;

\ True if addr is a definition colon (start of buffer or blank before ':').
: DBG-RUNTO-DEF-COLON?  ( addr -- flag )
  {: addr -- :}
  addr C@ [CHAR] : <> IF  FALSE EXIT  THEN
  addr DBG-ED-TBUF = IF  TRUE EXIT  THEN
  addr DBG-ED-TBUF U< IF  FALSE EXIT  THEN
  addr 1- C@ DBG-BLANK? ;

\ From a file-relative UTF-8 click offset, walk backward to the enclosing
\ `: name`, FIND it, return CFA. Used when the paused CFA is a caller
\ (e.g. MAIN) and the click is in a callee body (e.g. MAINX).
\ `target` is file-relative (same as RUNTO-OFF / map SLOT-OFF), not a buffer addr.
: DBG-RUNTO-CFA-AT-OFF  ( target-off -- cfa|0 )
  {: target | scan after a u xt cfa beg end -- :}
  0 TO cfa
  DBG-ED-TBUF 0= IF  0 EXIT  THEN
  \ Reject off past the bound buffer; then convert to absolute address.
  target DBG-ED-TEND DBG-ED-TBUF - U< 0= IF  0 EXIT  THEN
  DBG-ED-TBUF target + TO target
  target TO scan
  BEGIN  cfa 0=  scan DBG-ED-TBUF U< 0= AND  WHILE
     scan DBG-RUNTO-DEF-COLON? IF
        scan 1+ TO after
        BEGIN
           after DBG-ED-TEND U< IF  after C@ DBG-BLANK?  ELSE  FALSE  THEN
        WHILE
           after 1+ TO after
        REPEAT
        after DBG-ED-TEND U< IF
           \ Length of whitespace-delimited name (Forth token).
           after TO a
           BEGIN
              a DBG-ED-TEND U< IF
                 a C@ DBG-BLANK? 0=
                 a C@ [CHAR] \ <> AND
              ELSE
                 FALSE
              THEN
           WHILE
              a 1+ TO a
           REPEAT
           a after - TO u
           u IF
              after u DBG-ED-FIND IF
                 TO xt
                 \ Colon / CREATE CFA is the xt for FIND of a colon name.
                 xt TO cfa
                 cfa DBG-MAP-SRC-WINDOW TO end TO beg
                 beg IF
                    \ Include `: name` (scan..beg) so a click on the header
                    \ still associates with this definition; body is beg..end.
                    target scan >= target end < AND 0= IF
                       0 TO cfa   \ name hit but click outside this def
                    THEN
                 THEN
              THEN
           THEN
        THEN
     THEN
     scan DBG-ED-TBUF = IF
        0 TO scan   \ force exit
     ELSE
        scan 1- TO scan
     THEN
  REPEAT
  cfa ;

\ Resolve file-relative UTF-8 offset to call-site IP and arm (RUNTO-IP).
\ ior: 0 = ok; -1 = no pause CFA; -2 = no source file; -3 = offset not in any span.
: (RUNTO-RESOLVE)  ( utf8-off -- ior )
  {: off | cfa cmap cell# file# fsec other -- :}
  DBG-CFA@ TO cfa
  cfa 0= IF  -1 EXIT  THEN
  cfa VIEW-FILE# TO file#
  file# 0= IF  -2 EXIT  THEN
  file# DBG-MAP-ENSURE-FILE TO fsec
  fsec IF  fsec file# DBG-MAP-LOAD-FILE-BUF DROP  THEN
  DBG-ED-TBUF 0= IF  -2 EXIT  THEN

  \ 1) Paused CFA map (usual case: click inside the word you are in).
  cfa DBG-MAP-FIND-CFA TO cmap
  cmap 0= IF
     cfa DBG-MAP-BUILD
     cfa DBG-MAP-FIND-CFA TO cmap
  THEN
  cmap IF
     cmap DBG-CMAP-TBUF@ DBG-ED-TBUF <> IF
        cfa DBG-MAP-BUILD
        cfa DBG-MAP-FIND-CFA TO cmap
     THEN
  THEN
  cmap IF
     cmap off DBG-MAP-FIND-OFF TO cell#
     cell# 0< 0= IF
        cfa >BODY cell# CELLS + (RUNTO-IP)
        0 EXIT
     THEN
  THEN

  \ 2) Any already-built cmap for this file (prior pauses / sibling defs).
  fsec off DBG-RUNTO-SCAN-CMAPS TO cell# TO cmap
  cmap IF
     cmap DBG-CMAP-CFA@ >BODY cell# CELLS + (RUNTO-IP)
     0 EXIT
  THEN

  \ 3) Click is in another definition in this file (e.g. MAINX while in MAIN).
  off DBG-RUNTO-CFA-AT-OFF TO other
  other IF
     other DBG-MAP-BUILD
     other DBG-MAP-FIND-CFA TO cmap
     cmap IF
        cmap off DBG-MAP-FIND-OFF TO cell#
        cell# 0< 0= IF
           other >BODY cell# CELLS + (RUNTO-IP)
           0 EXIT
        THEN
     THEN
  THEN

  -3 ;

: DBG-RUNTO-ERR.  ( ior -- )
  DBG-CURSOR-OFF
  CASE
     -1 OF  ." runto: no paused definition" CR  ENDOF
     -2 OF  ." runto: paused word has no source file / map" CR  ENDOF
     -3 OF  ." runto: token not in debugger map (save file? wrong def?)" CR  ENDOF
     ." runto: cannot resolve offset in debugger map" CR
  ENDCASE
  DBG-CURSOR-ON ;

\ Pause-UI entry for key 135. True → caller should DBG-GO (keep-armed).
: (DBG-RUNTO-DO)  ( -- flag )
  RUNTO-OFF@ (RUNTO-RESOLVE) DUP IF
     DUP RUNTO-STATUS!
     DBG-RUNTO-ERR.
     DROP FALSE
  ELSE
     DROP
     1 RUNTO-STATUS!
     TRUE
  THEN ;

' (DBG-RUNTO-DO) IS DBG-RUNTO-DO
