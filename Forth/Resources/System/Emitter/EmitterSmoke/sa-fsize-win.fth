\ sa-fsize-win.fth — headless EMIT-WINDOW-APP reads FILE-SIZE.
\ FILE-SIZE ( fileid -- ud ior ), high cell on top. Not FILE-POSITION.
\
\   FROMLIB FLOAD Emitter/emitter.fth
\   S" System/Emitter/EmitterSmoke/sa-fsize-win.fth" INCLUDED

ONLY FORTH DEFINITIONS DECIMAL
FROMLIB FLOAD Emitter/emitter.fth

\ 100-byte source. The emitted app must report that length.
PAD 100 CHAR A FILL
S" /tmp/ef-fsize-src.txt" W/O CREATE-FILE THROW
>R  PAD 100 R@ WRITE-FILE THROW  R> CLOSE-FILE THROW

CREATE FS-OUT  2 CELLS ALLOT

\ Runs inside the window wrap, after WINDOW. Headless open returns -1
\ and WINDOW leaves the grid closed; the file words still run.
: FS-GO  ( -- )
  S" /tmp/ef-fsize-src.txt" R/O OPEN-FILE IF  DROP EXIT  THEN
  >R
  R@ FILE-SIZE IF  R> DROP 2DROP EXIT  THEN
  FS-OUT CELL+ !
  FS-OUT !
  R> CLOSE-FILE DROP
  S" /tmp/ef-fsize-out.txt" W/O CREATE-FILE IF  DROP EXIT  THEN
  >R
  FS-OUT 16 R@ WRITE-FILE DROP
  R> CLOSE-FILE DROP ;

ONLY FORTH ALSO SYSVOC ALSO EMITTER
S" /tmp" EMIT-WINDOW-APP-TO FS-GO
\ IF/THEN are compile-only. Literals 16 and 100 are parsed here, after EMIT.
DECIMAL

: (FS-CHECK)  ( -- )
  S\" EMIT_HEADLESS=1 /tmp/FS-GO.app/Contents/MacOS/FS-GO" SYSTEM
  IF  ." FAIL: headless FS-GO exited non-zero" CR ABORT  THEN

  S" /tmp/ef-fsize-out.txt" R/O OPEN-FILE THROW
  >R
  PAD 16 R@ READ-FILE THROW  DUP 16 <> IF
    ." FAIL: size file length " . CR ABORT
  THEN
  DROP
  PAD @ 100 <> IF
    ." FAIL: FILE-SIZE low " PAD @ . CR ABORT
  THEN
  PAD CELL+ @ IF
    ." FAIL: FILE-SIZE high " PAD CELL+ @ . CR ABORT
  THEN
  R> CLOSE-FILE DROP
  S" /tmp/ef-fsize-src.txt" DELETE-FILE DROP
  S" /tmp/ef-fsize-out.txt" DELETE-FILE DROP
  ;
(FS-CHECK)
CR .( sa-fsize-win: OK ) CR
