JULIAV444 for EditForth
------------------------

Jos v.d. Ven, Win32Forth, public domain. The z^2+c formula is
Marcel Hendrix, iForth, April 1994. This copy draws into the
TRUECOLOR graphics window. S saves the picture. The dialog
offers JPEG, PNG, or TIFF. L loads a parameter file and
draws that view. Sound is not included. One thread draws
the picture. A key during a pass stops that pass. S and L
wait until the pass finishes.

Load
  FROMLIB FLOAD Juliav444/JULIAV444.fth
  JULIAV444

JULIAV444-CORE4.fth is the same walker on four worker cores.
Load
  FROMLIB FLOAD Juliav444/JULIAV444-CORE4.fth
  JULIAV444-CORE4

JULIAV444-CORE8.fth splits the columns across eight cores.
Load
  FROMLIB FLOAD Juliav444/JULIAV444-CORE8.fth
  JULIAV444-CORE8

JULIAV444-CORE20.fth draws twenty column bands on ten
processors. This Mac has 4 performance cores and 6 efficiency
cores. The first ten bands start at once. Each later band
waits. The processor that finishes takes the oldest waiting
band, so a performance core can finish two or more bands
while an efficiency core is still on its first.
Load
  FROMLIB FLOAD Juliav444/JULIAV444-CORE20.fth
  JULIAV444-CORE20

Load one of these files in a session. CORE4 and CORE8 both
define JV-TA through JV-TD, so the second TASK: aborts.
CORE20 defines JV-T00 through JV-T19. Restart before loading
another Julia file.

The console task owns the window, the keys, and PREFRESH.
Each task keeps xx, yy, and the other pixel temps in its
own PAD. The drawing tasks do not PAUSE. CORES-JOIN returns
before the next frame starts. A click still zooms once. The
button comes up after that join, before the next frame is
scheduled. Q or Esc still returns to the console.
JV-SELFTEST prints juliav444-core4-ok, juliav444-core8-ok,
or juliav444-core20-ok. It also checks the column split.
CORE4 checks that four tasks match the console on four
pixels. CORE8 does that and checks that slots 4 through 7
each store their own number. CORE20 checks that the
processor which finished first runs the ten bands that were
waiting. A fixed share of two bands per processor times out.

JULIAV444's JV-SELFTEST checks the degree table, one interior
Mandelbrot pixel, one escaping pixel, and one pixel of each
Julia style. It does not open a window. It prints juliav444-ok.

Pixels use Library/FixPoint at the default 28 fraction bits.
Do not set XBITS before this file. XSIN and XCOS use constants
written for 28 bits. The pixel loop is X*, cell + and -, and 2*.
The plot is L!. A commented ARM64 sketch of that step is in the
source header. It is not a CODE word.

Zoom-in stops when the fixed step for one pixel becomes 0.
From the opening view that is about twenty zooms. Color sines
are the original 0..90 degree table. Cameleon's bailout is a
square root. Its iterate is still z^2+c. A standard Julia that
never escapes is black.

The window opens at 144 by 48 cells, 1152 by 768 pixels. The
graphics cap is 384 by 192 cells, 3072 by 3072 pixels.

The saved view dualblackhole is a Mandelbrot frame one
millionth wide. At 28 fraction bits that span is about 268
units. Across 1152 pixels the step is 0, so the picture is
flat. spiral is wider and still has a step. The preset
iteration counts 280 and 710 are kept. The + and - keys do
not change a preset that is already outside their range.

Keys
  1..8     standard, anti-julia, extreme, extreme-anti,
           cameleon, tiger, snake, tentacle
  M J      Mandelbrot or Julia
  V        spiral, wow, dualblackhole, MultiEyed
  R        random slides
  Space    hold the slide when that frame finishes.
           S waits for the finished frame and saves it.
           Any other key still stops the pass.
           After each slide the next one waits 2 seconds.
           5000 JV-WAIT ! changes that wait. 0 skips it.
  S        save the picture. The dialog offers JPEG, PNG,
           or TIFF. During a pass, S waits until that
           frame finishes.
  L        load a parameter file. During a pass, L waits
           until that frame finishes, then opens the file
           and draws that view. A missing key keeps its
           current value. Xx and Yy in the file are ignored.
  X        swap the two colors
  C        Julia: swap colors. Mandelbrot: tiger interior
  H Home   reset the walker that is on screen
  + -      Julia detail by 1, from 0 to 80.
           Mandelbrot detail by 10, from 3 to 400.
           = is accepted as +.
  PgUp     Mandelbrot distance times 1.3.
           Julia zoom factor and step times 1.2.
  PgDn     the same, divided
  Q Esc    return to the console

There is no menu. ? paints the key list on a medium green
band. Any key clears that list and restores the picture.

A left click centers that pixel and zooms both axes in by 2.
Option-click centers there and zooms out by 2. The zoom-in
stops when one pixel no longer has a fixed step. Right click
and middle click do nothing.

Julia arrows slide the picture with the key. Up and Down
change fposy, the vertical complex coordinate. Left and Right
change fposx, the horizontal one. Shift-Up zooms the vertical
axis in. Shift-Down zooms it out. Shift-Right zooms the
horizontal axis in. Shift-Left zooms it out.

Mandelbrot arrows move the window. Up and Left add the step
to both ends of that axis. Down and Right subtract it, so the
picture slides against the vertical arrows. Shift-Right and
Shift-Up move both ends inward. Shift-Left and Shift-Down
zoom that axis out. Pattern up is P. Pattern down is O.
Q quits in this copy, so O takes the original pattern-down key.

Mandelbrot B restores the black interior. D and E raise and
lower distortion.
