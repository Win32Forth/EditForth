\ SWINDOW.fth — sample popup message
\
\ Tom Zimmer. The DOS program saved the text screen, drew a box, and
\ restored the screen after a key. The EditForth console does not keep
\ a restorable text image, so this copy prints the box and waits for a
\ key. It runs on EditForth and EditForthPWA.
\
\ Load:
\   FROMLIB FLOAD Sample/SWINDOW.fth
\   SWINDOW
\
\ Public domain.

[DEFINED] ANEW [IF] ANEW SWINDOW_MODULE [THEN]

ONLY FORTH DEFINITIONS
DECIMAL

: SWINDOW ( -- )
  CR ." +--------------------------------------------------+"
  CR ." |        This is a sample POPUP window            |"
  CR ." |    Screen attributes can be used as well        |"
  CR ." |  Press a key to return to the console           |"
  CR ." +--------------------------------------------------+"
  CR
  KEY DROP
  CR ." SWINDOW finished." CR ;

CR .( Run: SWINDOW ) CR
