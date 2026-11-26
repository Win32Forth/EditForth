\ SOWM-EF.fth — EditForth screen for the SOWM policy.
\
\ One TRUECOLOR window. Each client is a rectangle on the current desktop.
\ Pointer origin matches PLOT: bottom-left, Y up. The top character row is
\ the status line and is not part of the desktop.
\
\ Load:
\   S" /Users/thomaszimmer/Documents/EditForth/SOWM/SOWM-EF.fth" INCLUDED
\   S" /Users/thomaszimmer/Documents/EditForth/SOWM/BALL.fth" INCLUDED
\   S" /Users/thomaszimmer/Documents/EditForth/SOWM/LINES.fth" INCLUDED
\   SOWM
\
\ Each program links itself. Both stay linked. SOWM opens one window
\ of each. Command-G opens the next program in that list, starting
\ with the ball.
\
\ Pointer
\   Move             focus under the pointer
\   Left drag        move
\   Right drag       resize from the bottom-left corner
\ Plain keys go to the focused window. Window commands use Command.
\ Control sets the same bit while this window is key, so it matches.
\   Esc                  back to the console
\   Command-Return       new empty window (Command-Space does this too)
\   Command-F            fullscreen toggle
\   Command-C            center
\   Command-Q            remove the focused window
\   Command-N / P        next / previous, and raise it
\   Command-1..6         desktop
\   Command-Option-1..6  send the focused window
\   Command-= or +       counter
\   Command-K            clock
\   Command-T            transcript
\   Command-G            next linked program (ball, then lines, then ball)
\
\ The content box sits inside the border, under the title. A graphics
\ program draws there with SOWM-PLOT, SOWM-LINE, and SOWM-RECT. Those words
\ are in FORTH, so a file loaded after SOWM can call them. Local (0,0) is
\ the bottom-left of that box. The host clears the body, then the program
\ draws again on each frame it is visible. A hidden window still steps, and
\ the step reads the current content size.
\
\ An empty window keeps the characters you type. The counter and the clock
\ do not take keystrokes. The linked program chooses for itself, in the
\ keys flag it passes to SOWM-LINK. The pixel font draws letters in capitals.
\ Enter stores a new line. Backspace deletes.
\
\ Public domain.

ONLY FORTH DEFINITIONS
DECIMAL
[DEFINED] ANEW [IF] ANEW SOWM_EF_MODULE [THEN]

S" SOWM.fth" INCLUDED

: SOWM-BYE ( -- )
  CR ." SOWM closed." CR
;

: SOWM-NOWIN ( -- )
  CR ." SOWM could not open the graphics window." CR
;

: EF-KEYS-OK ( -- )
  ." keys-ok " CR
;

ONLY FORTH ALSO GRAPHICS DEFINITIONS
DECIMAL

VARIABLE EF-PREV   0 EF-PREV !
VARIABLE EF-DONE   0 EF-DONE !
VARIABLE EF-X
VARIABLE EF-Y
VARIABLE EF-HOT
VARIABLE FX
VARIABLE FY
VARIABLE FW
VARIABLE FH
VARIABLE FC
VARIABLE SP-A
VARIABLE EF-WX
VARIABLE EF-WY
VARIABLE EF-WW
VARIABLE EF-WH
VARIABLE EF-TX
VARIABLE EF-TY
VARIABLE EF-TW
VARIABLE EF-TH
VARIABLE EF-TA
VARIABLE EF-TU
VARIABLE EF-COL
VARIABLE EF-ROW
VARIABLE EF-COLS
VARIABLE EF-ROWS
VARIABLE EF-WRAP
VARIABLE EF-SKIP
VARIABLE EF-SHOW
VARIABLE EF-GX
VARIABLE EF-GY
VARIABLE EF-GB
VARIABLE SB-X0
VARIABLE SB-Y0
VARIABLE SB-X1
VARIABLE SB-Y1
VARIABLE SB-DX
VARIABLE SB-DY
VARIABLE SB-SX
VARIABLE SB-SY
VARIABLE SB-ERR

: EF-DESK-COLOR ( -- color )
  SOWM-DESK@ 1-
  DUP 0 = IF DROP $20242C EXIT THEN
  DUP 1 = IF DROP $242820 EXIT THEN
  DUP 2 = IF DROP $282420 EXIT THEN
  DUP 3 = IF DROP $202428 EXIT THEN
  DUP 4 = IF DROP $242028 EXIT THEN
  DROP $202828
;

: EF-MEASURE ( -- )
  G-PX  G-PY G-CELLH - 1 MAX  SOWM-SCREEN
;

\ One pixel run. color is $00RRGGBB. XY>ADDR flips Y.
: EF-SPAN ( x y w color -- )
  $FF000000 OR >R
  ROT ROT XY>ADDR SP-A !
  DUP 1 < IF DROP R> DROP EXIT THEN
  R@ SP-A @ L!
  DUP 1 = IF DROP R> DROP EXIT THEN
  1- 4 * >R
  SP-A @  SP-A @ 4 +  R> CMOVE
  R> DROP
;

: EF-FILL ( x y w h color -- )
  FC !  FH !  FW !  FY !  FX !
  FW @ 1 < FH @ 1 < OR IF EXIT THEN
  FX @ 0< IF
    FW @ FX @ + FW !
    0 FX !
  THEN
  FY @ 0< IF
    FH @ FY @ + FH !
    0 FY !
  THEN
  FW @ 1 < FH @ 1 < OR IF EXIT THEN
  FX @ G-PX >= IF EXIT THEN
  FY @ G-PY >= IF EXIT THEN
  FX @ FW @ + G-PX > IF G-PX FX @ - FW ! THEN
  FY @ FH @ + G-PY > IF G-PY FY @ - FH ! THEN
  FW @ 1 < FH @ 1 < OR IF EXIT THEN
  FH @ 0 DO
    FX @  FY @ I +  FW @  FC @  EF-SPAN
  LOOP
;

\ 5x7 glyphs, ASCII 32..90. Bit 4 ($10) is the left pixel.
CREATE EF-FONT
  $00 C, $00 C, $00 C, $00 C, $00 C, $00 C, $00 C,
  $04 C, $04 C, $04 C, $04 C, $00 C, $04 C, $00 C,
  $0A C, $0A C, $00 C, $00 C, $00 C, $00 C, $00 C,
  $0A C, $1F C, $0A C, $0A C, $1F C, $0A C, $00 C,
  $04 C, $0F C, $14 C, $0E C, $05 C, $1E C, $04 C,
  $11 C, $12 C, $02 C, $04 C, $08 C, $09 C, $11 C,
  $0C C, $12 C, $08 C, $0C C, $15 C, $12 C, $0D C,
  $04 C, $04 C, $00 C, $00 C, $00 C, $00 C, $00 C,
  $02 C, $04 C, $08 C, $08 C, $08 C, $04 C, $02 C,
  $08 C, $04 C, $02 C, $02 C, $02 C, $04 C, $08 C,
  $00 C, $0A C, $04 C, $1F C, $04 C, $0A C, $00 C,
  $00 C, $04 C, $04 C, $1F C, $04 C, $04 C, $00 C,
  $00 C, $00 C, $00 C, $00 C, $04 C, $04 C, $08 C,
  $00 C, $00 C, $00 C, $1F C, $00 C, $00 C, $00 C,
  $00 C, $00 C, $00 C, $00 C, $00 C, $04 C, $04 C,
  $01 C, $02 C, $02 C, $04 C, $08 C, $08 C, $10 C,
  $0E C, $11 C, $13 C, $15 C, $19 C, $11 C, $0E C,
  $04 C, $0C C, $04 C, $04 C, $04 C, $04 C, $0E C,
  $0E C, $11 C, $01 C, $02 C, $04 C, $08 C, $1F C,
  $0E C, $11 C, $01 C, $06 C, $01 C, $11 C, $0E C,
  $02 C, $06 C, $0A C, $12 C, $1F C, $02 C, $02 C,
  $1F C, $10 C, $1E C, $01 C, $01 C, $11 C, $0E C,
  $06 C, $08 C, $10 C, $1E C, $11 C, $11 C, $0E C,
  $1F C, $01 C, $02 C, $04 C, $08 C, $08 C, $08 C,
  $0E C, $11 C, $11 C, $0E C, $11 C, $11 C, $0E C,
  $0E C, $11 C, $11 C, $0F C, $01 C, $02 C, $0C C,
  $00 C, $04 C, $04 C, $00 C, $04 C, $04 C, $00 C,
  $00 C, $04 C, $04 C, $00 C, $04 C, $04 C, $08 C,
  $02 C, $04 C, $08 C, $10 C, $08 C, $04 C, $02 C,
  $00 C, $00 C, $1F C, $00 C, $1F C, $00 C, $00 C,
  $08 C, $04 C, $02 C, $01 C, $02 C, $04 C, $08 C,
  $0E C, $11 C, $01 C, $02 C, $04 C, $00 C, $04 C,
  $0E C, $11 C, $17 C, $15 C, $17 C, $10 C, $0E C,
  $0E C, $11 C, $11 C, $1F C, $11 C, $11 C, $11 C,
  $1E C, $11 C, $11 C, $1E C, $11 C, $11 C, $1E C,
  $0E C, $11 C, $10 C, $10 C, $10 C, $11 C, $0E C,
  $1E C, $11 C, $11 C, $11 C, $11 C, $11 C, $1E C,
  $1F C, $10 C, $10 C, $1E C, $10 C, $10 C, $1F C,
  $1F C, $10 C, $10 C, $1E C, $10 C, $10 C, $10 C,
  $0E C, $11 C, $10 C, $17 C, $11 C, $11 C, $0E C,
  $11 C, $11 C, $11 C, $1F C, $11 C, $11 C, $11 C,
  $0E C, $04 C, $04 C, $04 C, $04 C, $04 C, $0E C,
  $07 C, $02 C, $02 C, $02 C, $02 C, $12 C, $0C C,
  $11 C, $12 C, $14 C, $18 C, $14 C, $12 C, $11 C,
  $10 C, $10 C, $10 C, $10 C, $10 C, $10 C, $1F C,
  $11 C, $1B C, $15 C, $15 C, $11 C, $11 C, $11 C,
  $11 C, $19 C, $15 C, $13 C, $11 C, $11 C, $11 C,
  $0E C, $11 C, $11 C, $11 C, $11 C, $11 C, $0E C,
  $1E C, $11 C, $11 C, $1E C, $10 C, $10 C, $10 C,
  $0E C, $11 C, $11 C, $11 C, $15 C, $12 C, $0D C,
  $1E C, $11 C, $11 C, $1E C, $14 C, $12 C, $11 C,
  $0E C, $11 C, $10 C, $0E C, $01 C, $11 C, $0E C,
  $1F C, $04 C, $04 C, $04 C, $04 C, $04 C, $04 C,
  $11 C, $11 C, $11 C, $11 C, $11 C, $11 C, $0E C,
  $11 C, $11 C, $11 C, $11 C, $11 C, $0A C, $04 C,
  $11 C, $11 C, $11 C, $15 C, $15 C, $1B C, $11 C,
  $11 C, $11 C, $0A C, $04 C, $0A C, $11 C, $11 C,
  $11 C, $11 C, $0A C, $04 C, $04 C, $04 C, $04 C,
  $1F C, $01 C, $02 C, $04 C, $08 C, $10 C, $1F C,

: EF-GLYPH ( c -- addr )
  DUP [CHAR] a [CHAR] z 1+ WITHIN IF 32 - THEN
  32 -
  DUP 0 59 WITHIN 0= IF DROP 0 THEN
  7 * EF-FONT +
;

: EF-DOT ( x y -- )
  DUP 0< IF 2DROP EXIT THEN
  DUP G-PY >= IF 2DROP EXIT THEN
  DUP EF-TY @ < IF 2DROP EXIT THEN
  DUP EF-TY @ EF-TH @ + >= IF 2DROP EXIT THEN
  OVER 0< IF 2DROP EXIT THEN
  OVER G-PX >= IF 2DROP EXIT THEN
  OVER EF-TX @ < IF 2DROP EXIT THEN
  OVER EF-TX @ EF-TW @ + >= IF 2DROP EXIT THEN
  XY>ADDR
  $D8DCE6 $FF000000 OR SWAP L!
;

\ ( c col row -- ) row 0 is the top line of the text box.
: EF-GLYPH-AT ( c col row -- )
  8 * EF-TY @ EF-TH @ + 1- SWAP - EF-GY !
  6 * EF-TX @ + EF-GX !
  EF-GLYPH
  7 0 DO
    DUP C@ EF-GB !
    5 0 DO
      EF-GB @ $10 AND IF
        EF-GX @ I + EF-GY @ J - EF-DOT
      THEN
      EF-GB @ 2* EF-GB !
    LOOP
    1+
  LOOP
  DROP
;

: EF-END-LINE ( -- )
  1 EF-ROW +!
  0 EF-COL !
;

: EF-FEED ( c -- )
  DUP 10 = IF
    DROP
    EF-WRAP @ 0= IF EF-END-LINE THEN
    0 EF-WRAP !
    EXIT
  THEN
  EF-SHOW @ IF
    EF-ROW @ EF-SKIP @ -
    DUP 0< IF
      DROP DROP
    ELSE
      DUP EF-ROWS @ >= IF
        DROP DROP
      ELSE
        >R EF-COL @ R> EF-GLYPH-AT
      THEN
    THEN
  ELSE
    DROP
  THEN
  1 EF-COL +!
  EF-COL @ EF-COLS @ >= IF
    EF-END-LINE
    -1 EF-WRAP !
  ELSE
    0 EF-WRAP !
  THEN
;

: EF-WALK ( -- )
  0 EF-COL !
  0 EF-ROW !
  0 EF-WRAP !
  EF-TU @ 0 ?DO
    EF-TA @ I + C@ EF-FEED
  LOOP
;

: EF-PAINT-TEXT ( -- )
  EF-TW @ 6 / EF-COLS !
  EF-TH @ 8 / EF-ROWS !
  EF-COLS @ 1 < EF-ROWS @ 1 < OR IF EXIT THEN
  0 EF-SHOW !
  EF-WALK
  EF-COL @ IF 1 EF-ROW +! THEN
  EF-ROW @ EF-ROWS @
  2DUP > IF - ELSE 2DROP 0 THEN
  EF-SKIP !
  -1 EF-SHOW !
  EF-WALK
;

: EF-TEXT ( id -- )
  DUP SOWM-LIVE? 0= IF DROP EXIT THEN
  SOWM-TEXT EF-TU ! EF-TA !
  EF-TU @ 0= IF EXIT THEN
  EF-PAINT-TEXT
;

\ Output words live in FORTH. A program loaded after SOWM can call them
\ without putting GRAPHICS in front of ." and .
ONLY FORTH DEFINITIONS ALSO GRAPHICS

VARIABLE SOWM-INK

\ Local pixel. Off-box points are dropped. Ink is $00RRGGBB.
: SOWM-PLOT ( x y -- )
  SOWM-XY 0= IF 2DROP EXIT THEN
  DUP 0 G-PY WITHIN 0= IF 2DROP EXIT THEN
  OVER 0 G-PX WITHIN 0= IF 2DROP EXIT THEN
  G-PIX 0= IF 2DROP EXIT THEN
  XY>ADDR
  SOWM-INK @ $FF000000 OR SWAP L!
;

\ Bresenham in content-box coordinates. Kernel LINE is the whole window.
: SOWM-LINE ( x0 y0 x1 y1 -- )
  SB-Y1 ! SB-X1 ! SB-Y0 ! SB-X0 !
  SB-X1 @ SB-X0 @ - DUP 0< IF NEGATE -1 ELSE 1 THEN SB-SX ! ABS SB-DX !
  SB-Y1 @ SB-Y0 @ - DUP 0< IF NEGATE -1 ELSE 1 THEN SB-SY ! ABS SB-DY !
  SB-DX @ SB-DY @ - SB-ERR !
  BEGIN
    SB-X0 @ SB-Y0 @ SOWM-PLOT
    SB-X0 @ SB-X1 @ = SB-Y0 @ SB-Y1 @ = AND IF EXIT THEN
    SB-ERR @ 2*
    DUP SB-DY @ NEGATE > IF
      SB-DY @ NEGATE SB-ERR +!
      SB-SX @ SB-X0 +!
    THEN
    SB-DX @ < IF
      SB-DX @ SB-ERR +!
      SB-SY @ SB-Y0 +!
    THEN
  AGAIN
;

: SOWM-RECT ( x y w h color -- )
  >R
  SOWM-BOX 0= IF R> DROP EXIT THEN
  R> EF-FILL
;

ONLY FORTH ALSO GRAPHICS DEFINITIONS

\ Gold bar along the bottom of the content box. Width cycles with the count.
: EF-COUNT-DRAW ( -- )
  SOWM-CH @ 6 MIN
  DUP 1 < SOWM-CW @ 1 < OR IF DROP EXIT THEN
  >R
  SOWM-OUT @ F-PRIV F@ 20 MOD SOWM-CW @ * 20 /
  DUP 1 < IF DROP R> DROP EXIT THEN
  R>
  0 0 2SWAP
  $E6C36A SOWM-RECT
;

: EF-WIN ( id -- )
  DUP SOWM-FOCUS@ = EF-HOT !
  DUP SOWM-X@ SWAP
  DUP SOWM-Y@ SWAP
  DUP SOWM-W@ SWAP
  DUP SOWM-H@ SWAP
  >R
  FH ! FW ! FY ! FX !
  FX @ EF-WX !
  FY @ EF-WY !
  FW @ EF-WW !
  FH @ EF-WH !
  FX @ FY @ FW @ FH @
  EF-HOT @ IF $E6C36A ELSE $5C6574 THEN EF-FILL
  FX @ 3 +  FY @ 3 +  FW @ 6 -  FH @ 6 -  $3C4250 EF-FILL
  FX @ 3 +
  FY @ FH @ + 21 -
  FW @ 6 -
  18
  EF-HOT @ IF $6A5428 ELSE $2E3648 THEN EF-FILL
  EF-WX @ 5 + EF-TX !
  EF-WY @ 5 + EF-TY !
  EF-WW @ 10 - 0 MAX EF-TW !
  EF-WH @ 29 - 0 MAX EF-TH !
  R@ EF-TEXT
  R@ SOWM-OUT !
  R@ SOWM-VIEW SOWM-CLIP
  R@ F-DRAW F@ ?DUP IF
    EXECUTE
  THEN
  R> DROP
;

: EF-COUNTER ( -- )
  SOWM-COUNTER DUP 0= IF DROP EXIT THEN
  ['] EF-COUNT-DRAW SWAP SOWM-DRAW!
;

: EF-CLOCK ( -- ) SOWM-CLOCK DROP ;
: EF-NOTE ( -- ) SOWM-NOTE DROP ;

: EF-STATUS ( -- )
  ." d=" SOWM-DESK@ .
  ." n=" SOWM-COUNT .
  ." esc cmd-ret new f full c ctr q n/p 1-6 opt1 =cnt k clk t g next"
;

: EF-DRAW ( -- )
  EF-MEASURE
  0 0 G-PX SOWM-SH @ EF-DESK-COLOR EF-FILL
  ['] EF-WIN SOWM-EACH
  0 SOWM-SH @ G-PX G-CELLH $12141C EF-FILL
  0 0 AT EF-STATUS
  PREFRESH
;

: EF-BTN# ( mask -- n )
  DUP 1 AND IF DROP 1 EXIT THEN
  2 AND IF 2 ELSE 0 THEN
;

: EF-MOUSE ( -- )
  G-MOUSE 7 AND EF-BTN# >R
  EF-Y ! EF-X !
  R@ EF-PREV @ = IF
    R> IF
      EF-X @ EF-Y @ SOWM-MOTION
    ELSE
      EF-X @ EF-Y @ SOWM-HOVER
    THEN
  ELSE
    EF-PREV @ IF SOWM-UP THEN
    R@ IF R@ EF-X @ EF-Y @ SOWM-DOWN THEN
    R> EF-PREV !
  THEN
;

\ Drop Shift, Command, and Option. Command and Control share bit 512.
: EF-UNMOD ( c -- c )
  DUP 256 AND IF 256 XOR THEN
  DUP 512 AND IF 512 XOR THEN
  DUP 1024 AND IF 1024 XOR THEN
;

: EF-COMMANDS ( c -- )
  DUP 13 = OVER 10 = OR OVER BL = OR IF
    DROP SOWM-NEW DROP EXIT
  THEN
  DUP [CHAR] 1 [CHAR] 7 WITHIN IF
    [CHAR] 1 - 1+ SOWM-GO EXIT
  THEN
  DUP [CHAR] q = OVER [CHAR] Q = OR IF DROP SOWM-KILL EXIT THEN
  DUP [CHAR] c = OVER [CHAR] C = OR IF DROP SOWM-CENTER EXIT THEN
  DUP [CHAR] f = OVER [CHAR] F = OR IF DROP SOWM-FULL EXIT THEN
  DUP [CHAR] n = OVER [CHAR] N = OR IF DROP SOWM-NEXT EXIT THEN
  DUP [CHAR] p = OVER [CHAR] P = OR IF DROP SOWM-PREV EXIT THEN
  DUP [CHAR] = = OVER [CHAR] + = OR IF DROP EF-COUNTER EXIT THEN
  DUP [CHAR] k = OVER [CHAR] K = OR IF DROP EF-CLOCK EXIT THEN
  DUP [CHAR] t = OVER [CHAR] T = OR IF DROP EF-NOTE EXIT THEN
  DUP [CHAR] g = OVER [CHAR] G = OR IF DROP SOWM-NEXT-PROG DROP EXIT THEN
  DROP
;

: EF-KEY ( c -- )
  DUP 27 = IF DROP -1 EF-DONE ! EXIT THEN
  DUP 512 AND 0= IF
    SOWM-TAKES? IF SOWM-CHAR EXIT THEN
    DROP EXIT
  THEN
  DUP 1024 AND SWAP
  DUP 9 512 OR = IF 2DROP SOWM-NEXT EXIT THEN
  DUP 9 256 OR 512 OR = IF 2DROP SOWM-PREV EXIT THEN
  EF-UNMOD SWAP
  IF
    DUP [CHAR] 1 [CHAR] 7 WITHIN IF
      [CHAR] 1 - 1+ SOWM-SEND
    THEN
    DROP EXIT
  THEN
  EF-COMMANDS
;

\ Headless check for the Command-key split. Prints keys-ok.
: EF-KEY-TEST ( -- )
  SOWM-RESET
  800 600 SOWM-SCREEN
  SOWM-NEW 1 T=
  [CHAR] f EF-KEY
  BL EF-KEY
  [CHAR] 1 EF-KEY
  1 F-LEN F@ 3 T=
  1 SOWM-TPTR C@ [CHAR] f T=
  1 SOWM-TPTR 1+ C@ BL T=
  1 SOWM-TPTR 2 + C@ [CHAR] 1 T=
  SOWM-DESK@ 1 T=
  1 SOWM-FS@ 0 T=
  [CHAR] f 512 OR EF-KEY
  1 SOWM-FS@ -1 T=
  1 F-LEN F@ 3 T=
  [CHAR] 2 512 OR EF-KEY
  SOWM-DESK@ 2 T=
  1 F-DESK F@ 1 T=
  1 SOWM-GO
  [CHAR] 2 512 OR 1024 OR EF-KEY
  SOWM-DESK@ 1 T=
  1 F-DESK F@ 2 T=
  2 SOWM-GO
  [CHAR] q EF-KEY
  SOWM-COUNT 1 T=
  1 F-LEN F@ 4 T=
  [CHAR] q 512 OR EF-KEY
  SOWM-COUNT 0 T=
  [CHAR] = 512 OR EF-KEY
  SOWM-FOCUS@ F-KEYS F@ 0 T=
  \ Command-G opens a window only when a program is linked.
  SOWM-HOLD
  0 0 0 SOWM-LINK
  [CHAR] g 512 OR EF-KEY
  SOWM-COUNT 1 T=
  SOWM-FOCUS@ F-STEP F@ ['] SOWM-COUNT-STEP T=
  SOWM-HELD
  DEPTH 0 T=
  EF-KEYS-OK
;

: EF-RUN ( -- )
  S" SOWM" APP-NAME
  WINDOW
  G-OPEN? 0= IF SOWM-NOWIN EXIT THEN
  PIXEL-ON
  TRUECOLOR
  G-PIX 0= IF WINDOW-OFF SOWM-NOWIN EXIT THEN
  EF-MEASURE
  SOWM-RESET
  SOWM-NEW DROP SOWM-NEW DROP SOWM-NEW DROP
  SOWM-ATTACH-ALL
  0 EF-DONE !
  0 EF-PREV !
  BEGIN
    EF-DONE @ 0=
  WHILE
    (APP-PUMP)
    EF-MOUSE
    KEY? IF KEY EF-KEY THEN
    SOWM-TICK
    EF-DRAW
  REPEAT
;

ONLY FORTH DEFINITIONS ALSO GRAPHICS

: SOWM ( -- )
  EF-RUN
  EF-DONE @ IF
    1BIT
    WINDOW-OFF
    SOWM-BYE
  THEN
;

PREVIOUS
CR .( SOWM loaded — type SOWM to run.) CR
