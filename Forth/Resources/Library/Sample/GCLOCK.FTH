\ GCLOCK.FTH — Graphic Clock for 64Forth GRAPHICS (COLOR8)
\
\ Port of Tom Zimmer & Robert Smith GCLOCK.SEQ (public domain).
\ Original targeted TCOM / EGA 640x350x16; this version uses
\ 64Forth WINDOW + COLOR8 (640x400) like DOODLECOLOR64 / BRESENHAM.
\
\ Load (not Autoload):
\   FROMLIB FLOAD Sample/GCLOCK.FTH
\   GCLOCK
\
\ Controls (graphics window must have key focus):
\   Enter   more oblong / reshape border
\   Space   clear and redraw with a new random oblong
\   Esc     quit (returns to console; no BYE)
\
\ Public domain.

ANEW GCLOCK_MODULE

\ Emitter Autoload defines this; tolerate a bare kernel for compile smoke.
[DEFINED] EMIT-NO-WRAPPER [IF] EMIT-NO-WRAPPER [THEN]

ONLY FORTH DEFINITIONS
DECIMAL

: GCLOCK-CREDIT  ( -- )
  CR ." GCLOCK is a public domain example by Tom Zimmer and Robert Smith,"
  CR ." adapted for 64Forth GRAPHICS COLOR8 (640x400)." CR
  ;

\ Wall clock from TIME&DATE (local). Stand-alone emit relocates the
\ time_date_hook BLR via HOST-APP slot 27 (localtime_r in emit-host).
: HMS  ( -- hour min sec )
  TIME&DATE                   \ sec min hour day month year
  2DROP DROP                  \ sec min hour
  SWAP ROT                    \ hour min sec
  ;

ONLY FORTH ALSO GRAPHICS DEFINITIONS
DECIMAL

[UNDEFINED] 3DROP [IF]
: 3DROP  ( n1 n2 n3 -- )  DROP 2DROP ;
[THEN]

\ --- classic EGA-ish pens (COLOR8 indices) ---------------------------------

: PEN!     ( ix -- )  COLOR !  WHITE ;
: PEN-BLACK   ( -- )  BLACK ;
: PEN-WHITE   ( -- )  CWHITE   PEN! ;
: PEN-LTGREEN ( -- )  CLTGREEN PEN! ;
: PEN-LTBLUE  ( -- )  CLTBLUE  PEN! ;
: PEN-LTCYAN  ( -- )  CLTCYAN  PEN! ;
: PEN-YELLOW  ( -- )  CYELLOW  PEN! ;

\ Precomputed 6° sine table (absolute screen offsets for hand tips).
\ Built historically with F-PC + FFLOAT; kept as integer cells.
CREATE SINTBL
          0 ,    25 ,    49 ,    74 ,    97 ,   120 ,   141 ,   160 ,
        178 ,   194 ,   207 ,   219 ,   228 ,   234 ,   238 ,   240 ,
        238 ,   234 ,   228 ,   219 ,   207 ,   194 ,   178 ,   160 ,
        141 ,   119 ,    97 ,    74 ,    49 ,    25 ,     0 ,   -25 ,
        -49 ,   -74 ,   -97 ,  -120 ,  -141 ,  -160 ,  -178 ,  -194 ,
       -207 ,  -219 ,  -228 ,  -234 ,  -238 ,  -240 ,  -238 ,  -234 ,
       -228 ,  -219 ,  -207 ,  -194 ,  -178 ,  -160 ,  -141 ,  -119 ,
        -97 ,   -74 ,   -49 ,   -25 ,     0 ,    25 ,    49 ,    74 ,
         97 ,   120 ,   141 ,   160 ,   178 ,   194 ,   207 ,   219 ,
        228 ,   234 ,   238 ,   240 ,   238 ,

\ VARIABLEs so Emitter reach can see them in colon bodies.
\ Init lasts to 0 (not -1): negative 60 MOD can yield a bad SINTBL index.
VARIABLE LAST-HOUR           0 LAST-HOUR !
VARIABLE LAST-MINUTE         0 LAST-MINUTE !
VARIABLE LAST-HOUR-MINUTE    0 LAST-HOUR-MINUTE !
VARIABLE LAST-SECOND         0 LAST-SECOND !
VARIABLE THIS-HOUR           0 THIS-HOUR !
VARIABLE THIS-MINUTE         0 THIS-MINUTE !
VARIABLE THIS-SECOND         0 THIS-SECOND !

VARIABLE CENTER-X   320 CENTER-X !
VARIABLE CENTER-Y   199 CENTER-Y !
VARIABLE SCALE-Y    240 SCALE-Y !

VARIABLE OBLONG      0 OBLONG !
VARIABLE OBLONG2     0 OBLONG2 !

VARIABLE SEED1  0 SEED1 !
VARIABLE SEED2  0 SEED2 !
VARIABLE SEED3  0 SEED3 !

VARIABLE CCOLOR  0 CCOLOR !
VARIABLE CDIAM  16 CDIAM !

\ Last adopted pixel size — GC-ADOPT-WINDOW redraws when the live
\ resize finishes and G-PX/G-PY change (same pattern as IMAGEVIEW64).
VARIABLE GC-LAST-PX  0 GC-LAST-PX !
VARIABLE GC-LAST-PY  0 GC-LAST-PY !

: (RANDOMIZE)  ( -- u )  MS@ ;

: RANDOMIZE  ( -- )
  (RANDOMIZE)        SEED1 !
  (RANDOMIZE) 2* 1-  SEED2 !
  (RANDOMIZE) 2/ 1+  SEED3 !
  ;

: RND  ( n1 -- n2 )
  1 MAX
  SEED1 @ 177 /MOD  2*    SWAP  171 *  SWAP  - DUP  SEED1 !
  SEED2 @ 176 /MOD  35 *  SWAP  172 *  SWAP  - DUP  SEED2 !
  SEED3 @ 178 /MOD  63 *  SWAP  170 *  SWAP  - DUP  SEED3 !
  +  +  SWAP  MOD
  ;

\ 6deg index + radial scale → screen x y (bottom-left origin).
\ TCOM used 2* for cell indexing (16-bit cells). Here CELL=8 → CELLS.
\ TCOM negated Y for top-down EGA; 64Forth is y-up, so leave Y signed as-is
\ (ang 0 = 12 o'clock at top, increasing = clockwise).
: XY-SCALE  ( 6deg scale -- x1 y1 )
  >R
  DUP CELLS SINTBL + @  DUP R@  240 */
  SWAP DUP 1 AND  OBLONG2 @  ROT 2 AND IF NEGATE THEN
  * +  CENTER-X @ +
  SWAP 15 + CELLS SINTBL + @  DUP R>  SCALE-Y @ */
  SWAP DUP 1 AND  OBLONG2 @  ROT 2 AND IF NEGATE THEN
  * +  CENTER-Y @ +
  ;

\ Hand angle 0..59 (SINTBL index); keep non-negative after MOD.
: ANG  ( n -- n' )
  60 MOD  DUP 0< IF  60 +  THEN
  ;

: .SEC  ( n1 -- )
  ANG >R
  CENTER-X @ CENTER-Y @  R@     220 XY-SCALE  LINE
  R@ 1- ANG 020 XY-SCALE  R@     220 XY-SCALE  LINE
  R@ 1+ ANG 020 XY-SCALE  R@     220 XY-SCALE  LINE
  CENTER-X @ CENTER-Y @  R@ 1- ANG 020 XY-SCALE  LINE
  CENTER-X @ CENTER-Y @  R@ 1+ ANG 020 XY-SCALE  LINE
  R> DROP
  ;

: .MIN  ( n1 -- )
  ANG >R
  CENTER-X @ CENTER-Y @  R@     180 XY-SCALE  LINE
  R@ 1- ANG 100 XY-SCALE  R@     180 XY-SCALE  LINE
  R@ 1+ ANG 100 XY-SCALE  R@     180 XY-SCALE  LINE
  CENTER-X @ CENTER-Y @  R@ 1- ANG 100 XY-SCALE  LINE
  CENTER-X @ CENTER-Y @  R@ 1+ ANG 100 XY-SCALE  LINE
  R> DROP
  ;

: .HR  ( n1 -- )
  ANG >R
  CENTER-X @ CENTER-Y @  R@      120 XY-SCALE  LINE
  R@ 2 - ANG 060 XY-SCALE  R@      120 XY-SCALE  LINE
  R@ 2 + ANG 060 XY-SCALE  R@      120 XY-SCALE  LINE
  CENTER-X @ CENTER-Y @  R@ 2 - ANG 060 XY-SCALE  LINE
  CENTER-X @ CENTER-Y @  R@ 2 + ANG 060 XY-SCALE  LINE
  R> DROP
  ;

: .SECOND  ( -- )
  PEN-BLACK
  LAST-SECOND @ .SEC
  THIS-SECOND @ LAST-SECOND !
  PEN-WHITE
  THIS-SECOND @ .SEC
  ;

: .MINUTE  ( -- )
  PEN-BLACK
  LAST-MINUTE @ .MIN
  THIS-MINUTE @ LAST-MINUTE !
  PEN-LTGREEN
  THIS-MINUTE @ .MIN
  ;

: .HOUR  ( -- )
  PEN-BLACK
  LAST-HOUR @ 5 *  LAST-HOUR-MINUTE @ 12 /  +  .HR
  THIS-HOUR @ LAST-HOUR !
  THIS-MINUTE @ LAST-HOUR-MINUTE !
  PEN-LTBLUE
  THIS-HOUR @ 5 *  THIS-MINUTE @ 12 /  +  .HR
  ;

: ?SECOND  ( -- f )
  HMS                                   \ hour min sec
  DUP LAST-SECOND @ <>
  IF
    THIS-SECOND !
    THIS-MINUTE !
    THIS-HOUR !
    TRUE
  ELSE
    3DROP FALSE
  THEN
  ;

: INIT-VARS  ( -- )
  ?SECOND DROP
  THIS-SECOND @ LAST-SECOND !
  THIS-MINUTE @ LAST-MINUTE !
  THIS-MINUTE @ LAST-HOUR-MINUTE !
  THIS-HOUR @ LAST-HOUR !
  ;

: SHOW-CIRCLE  ( -- )
  CCOLOR @ 1+ CCOLOR !
  CCOLOR @ PEN!
  60 0 DO
    I CDIAM @ XY-SCALE PLOT
  LOOP
  CDIAM @ 5 + CDIAM !
  CDIAM @ 210 > IF  16 CDIAM !  THEN
  ;

: SHOW-BORDER  ( -- )
  \ Prefer UNLOOP EXIT over LEAVE — emitter COLON-WALK treats LEAVE like a
  \ branch with an offset cell and can "scan: overrun" (see reach.fth).
  60 0 DO
    KEY? IF  UNLOOP EXIT  THEN
    PEN-WHITE
    I 239 XY-SCALE  I 1+ ANG 239 XY-SCALE  LINE
    I 228 XY-SCALE  I 1+ ANG 228 XY-SCALE  LINE
    I 5 MOD
    IF
      PEN-LTCYAN
      I 228 XY-SCALE  I 239 XY-SCALE  LINE
    ELSE
      PEN-YELLOW
      I 220 XY-SCALE  I 239 XY-SCALE  LINE
    THEN
  LOOP
  PREFRESH                              \ pixels need PREFRESH; KEY? only ?REFRESH
  ;

: GC-LAYOUT  ( -- )
  G-PX 2/ CENTER-X !
  G-PY 2/ 1- CENTER-Y !
  240 240 CENTER-Y @ */ SCALE-Y !
  G-PX GC-LAST-PX !
  G-PY GC-LAST-PY !
  ;

: .CLOCK-INFO  ( -- )
  \ Character grid labels; col tracks G-COLS so they move with the face
  \ after a live resize (pixel blit stretch-scales; text uses cell AT).
  G-COLS 40 - 0 MAX 0 AT ." Tom & Bob's Graphic Clock"
  G-COLS 40 - 0 MAX 1 AT ." Esc=quit  Enter=reshape  Space=redraw"
  ;

: .HMS  ( -- )
  .SECOND
  .MINUTE
  .HOUR
  SHOW-CIRCLE
  PREFRESH
  ;

\ Full face + chrome after layout change (resize, Space, startup).
: GC-REDRAW  ( -- )
  COLOR8  PCLS
  .CLOCK-INFO
  SHOW-BORDER
  INIT-VARS
  .HMS
  ;

: NEW-CLOCK  ( -- )
  GC-LAYOUT
  OBLONG @ RND OBLONG2 !
  GC-REDRAW
  ;

\ Adopt host grid when the user finishes a live resize; redraw so the
\ help text and hands share the new G-PX×G-PY (not a stretched old frame).
: GC-ADOPT-WINDOW  ( -- )
  (APP-SIZE?) 0= IF  2DROP EXIT  THEN
  WINDOW-SIZE
  GC-LAYOUT
  GC-REDRAW
  ;

: SHOW-TIME  ( -- )
  ?SECOND
  IF
    THIS-SECOND @ 5 MOD 0=
    OBLONG @ 1 > AND
    IF  NEW-CLOCK  ELSE  .HMS  THEN
  THEN
  ;

: DO-CLOCK  ( -- )
  SHOW-BORDER
  INIT-VARS
  .HMS
  BEGIN
    BEGIN
      KEY? 0=
    WHILE
      GC-ADOPT-WINDOW
      SHOW-TIME
      \ Soft yield so AppKit can paint / take Esc (avoid beach-ball spin).
      16 MS
      (APP-PUMP)
    REPEAT
    KEY
    DUP 13 = IF                    \ Enter — more oblong
      DROP
      OBLONG @ 1+ OBLONG !
      OBLONG @ OBLONG2 !
      SHOW-BORDER
      .HMS
      FALSE
    ELSE DUP BL = IF               \ Space — new random face
      DROP  NEW-CLOCK  FALSE
    ELSE DUP 27 = IF               \ Esc — quit
      DROP  TRUE
    ELSE
      DROP  TRUE                   \ any other key quits
    THEN THEN THEN
  UNTIL
  ;

: GCLOCK  ( -- )
  DECIMAL
  RANDOMIZE
  S" 64Forth Graphic Clock" APP-NAME
  COLOR8  WINDOW  PCLS
  GC-LAYOUT
  PEN-WHITE
  .CLOCK-INFO
  DO-CLOCK
  WINDOW-OFF
  \ Do not ONLY/ALSO here — stand-alone emit has no CODE-BOUNDS for ONLY.
  GCLOCK-CREDIT
  ;

\ Keep GRAPHICS searchable for EMIT-WINDOW-APP; FORTH first for console CR.
ONLY FORTH ALSO GRAPHICS ALSO FORTH DEFINITIONS

CR .( GCLOCK — graphic clock; Esc quits) CR
CR .( Run:  GCLOCK ) CR
CR .( Emit: EMIT-WINDOW-APP GCLOCK ) CR
