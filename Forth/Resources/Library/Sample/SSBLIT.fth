\ SSBLIT.fth — Samsung logo and a moving Z
\
\ Port of TCOM SSBLIT.FTH (Tom Zimmer and Robert Smith, public domain).
\ The DOS program bit-blitted a 40 by 40 logo with EGA registers. This copy
\ plots the same bitmap on the GRAPHICS window. The first byte of the
\ original logo is skipped, matching the DOS blit. It runs on EditForth
\ and EditForthPWA.
\
\ Load:
\   FROMLIB FLOAD Sample/SSBLIT.fth
\   SSBLIT
\
\ Click the graphics window. Any key stops.
\
\ Public domain.

EMIT-NO-WRAPPER

ONLY FORTH DEFINITIONS
DECIMAL

: SSBLIT-CREDIT ( -- )
  CR ." SSBLIT draws the Samsung logo and a moving Z."
  CR ." Click the graphics window. Any key returns to the console." CR
  ;

ONLY FORTH ALSO GRAPHICS DEFINITIONS
DECIMAL

CREATE SS-ICON
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 0 C,
  1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C,
  1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C,
  1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C,
  1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C,
  0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C,
  0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C,
  0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C,
  0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C,
  0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C,
  0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C,
  0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C,
  0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C,
  1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C,
  1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C,
  1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C,
  1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 0 C,
  1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C,
  1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C,
  1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C,
  0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C,
  0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C,
  0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C,
  0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C,
  0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C,
  0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C,
  0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C,
  0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C,
  0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C,
  1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C,
  1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C,
  1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 0 C,
  1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,

CREATE Z-ICON
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 1 C, 1 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 1 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C,
  1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C,
  1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C,
  1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 1 C, 1 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  1 C, 1 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 1 C,
  1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C, 0 C, 1 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C,
  1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C,
  1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 1 C, 0 C, 0 C, 0 C, 0 C, 0 C, 1 C, 1 C, 1 C, 1 C,
  1 C, 1 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C,
  1 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 1 C, 1 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 1 C, 1 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 1 C, 1 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C,
  1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C,
  1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C,
  1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  1 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 1 C, 1 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 1 C, 1 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 1 C, 1 C, 1 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,
  0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C, 0 C,

VARIABLE RX
VARIABLE RY
VARIABLE RW
VARIABLE BA
VARIABLE BX
VARIABLE BY
VARIABLE ZX
2 CONSTANT SS-SC

: FILL-RECT ( x y w h -- )
  DUP 0= IF 2DROP 2DROP EXIT THEN
  >R
  RW ! RY ! RX !
  R> 0 DO
    RX @ RY @ I +
    RX @ RW @ + 1- RY @ I +
    LINE
  LOOP ;

: SS-BLIT ( addr x y -- )
  BY ! BX ! BA !
  40 0 DO
    40 0 DO
      BA @ J 40 * I + + C@ IF
        BX @ I SS-SC * +
        BY @ 39 J - SS-SC * +
        SS-SC SS-SC FILL-RECT
      THEN
    LOOP
  LOOP ;

: SSBLIT ( -- )
  DECIMAL
  S" EditForth SSBLIT" APP-NAME
  WINDOW PIXEL-ON COLOR8
  20 ZX !
  BEGIN
    \ Clear the maps only. PREFRESH waits until this frame is drawn.
    \ A blit of the empty map is what the page keeps until the next
    \ yield, so the finished picture never reaches the screen.
    PIX-ERASE
    G-BUF G-COLS G-ROWS * BL FILL
    14 COLOR !
    SS-ICON 80 160 SS-BLIT
    11 COLOR !
    Z-ICON ZX @ 48 SS-BLIT
    ZX @ 6 + DUP G-PX 160 - > IF DROP 20 THEN ZX !
    PREFRESH
    KEY?
  UNTIL
  KEY? IF KEY DROP THEN
  1BIT
  WINDOW-OFF
  ;

ONLY FORTH ALSO GRAPHICS ALSO FORTH DEFINITIONS

SSBLIT-CREDIT
CR .( Run:  SSBLIT ) CR
CR .( Emit: EMIT-WINDOW-APP SSBLIT ) CR
