EditForth System
================

Forth system sources that ship with the app, beside Library
(samples and other libraries).

  Assembler/   AArch64 assembler
  AutoLoad/    Product boot (autoload.fth)
  Debugger/    DEBUG / breakpoints (loaded by AutoLoad)
  Emitter/     Turnkey slicer
  Hyper/       VIEW / HYPER index
  Reference/   Forth 2012 text for Ask Forth
  Sources/     Shipped kernel sources for VIEW
  Testing/     ANSValidate, HayesTest, debugger smokes

Load with FROMLIB (those folder names resolve under System):

  FROMLIB FLOAD Debugger/debugger.fth
  FROMLIB FLOAD Emitter/emitter.fth
  FROMLIB FLOAD Testing/ANSValidate/ANS-VALIDATE.fth

Or from Documents/EditForth:

  REQUIRE System/Hyper/hyper.fth

AutoLoad requires Debugger, Emitter, and Hyper from this folder.
The Copy System build phase syncs Forth/Kernel into Sources/ and
copies this folder into the app.
