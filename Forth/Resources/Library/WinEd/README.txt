WINED64
======

A text editor that runs on EditForth. It is a translation of Tom Zimmer's
WinEd (wined.F, about March 23, 2002, later edits by others), not a
line-by-line port of the Windows calls.

Load it, then start it:

    FROMLIB FLOAD WinEd/WINED64.fth
    WINED64

The window is the GRAPHICS App Output window. Drag the corner while you
are editing. The text reflows to the new columns and rows. Esc leaves
that window. The red close button sends Esc. It is the graphics-window
exit, not an EditForth text command. A click on NEW, OPEN, SAVE, CLOSE,
NEXT, FIND, HELP, or QUIT runs that command. NEXT steps to the next of
eight file slots, including empty ones. Each slot keeps its own text.
NEW and OPEN pick an empty slot when the current one is already in use.
CLOSE drops the current slot. An empty slot shows (untitled).
Quit asks once for every dirty slot. The prompt names that file.
S saves it and goes on to the next dirty one. D discards it and
goes on. Esc cancels the quit and keeps every edit.
Opening a file allocates a buffer of twice the file size, and at
least 4096 bytes. Typing, paste, and replace grow that buffer.
A file is never truncated to fit.

Keyboard
--------

The bindings are the EditForth text commands. Command is the documented
key. Control does the same thing while this window is key.

    Command-N           New file
    Command-O           Open
    Command-S           Save
    Command-Shift-S     Save As
    Command-W           Close this file
    Command-Q           Leave the editor
    Command-F           Find
    Command-Shift-F     Find and Replace
    Command-G           Find Next
    Command-Shift-G     Find Previous
    Command-A           Select All
    Command-C           Copy
    Command-X           Cut
    Command-V           Paste
    Command-Z           Undo once
    Command-/           Toggle a leading "\ " on each selected line
    Command-Shift-B     Browse, or allow editing

    Arrows              Move the caret. Shift extends the selection.
    Option-Left/Right   Move by word. Shift extends the selection.
    Command-Left/Right  Beginning and end of the line.
    Command-Up/Down     Beginning and end of the file.
    Home / End          Beginning and end of the file.
    Page Up / Page Down A screenful. Shift extends the selection.
    Option-Page Up/Down Move to the next blank line.
    Tab                 Two spaces. In the find bar, Tab changes field.
    Shift-Tab           The other find field.
    Enter               New line. In the find bar, find next.
                        In Find and Replace, Enter replaces and finds next.
    Insert              Insert or overstrike.
    Delete              Forward delete.
    Esc                 Close the find bar, cancel a save question,
                        or leave the editor. Command-Q leaves the
                        editor the same way. A dirty file asks
                        S to save, D to discard, Esc to keep editing.

A click places the caret. Extend a selection with Shift and a motion key.
A line longer than the window scrolls sideways. It does not wrap.

Command-C, Command-X, and Command-V use a buffer inside this editor.
They do not read or write the Mac clipboard.

Command-/ adds "\ " at the start of each line the selection touches. A
caret with no selection toggles that line. The mark is removed only when
every non-empty line in the span already has it. Browse mode does not
change the text.

Find is case-insensitive and does not wrap. The bar is the second row.
Typed characters go into that bar. Arrows still move the caret. An
underscore marks the active field. Esc closes the bar and does not quit.

These EditForth commands are not editor commands here. They belong to
the text view and the debugger: Command-\ and F9 (breakpoint), F5 through
F8, Control-Command-Y (Break Now), Command-K (clear the console),
Command-Shift-L (FLOAD), Command-Shift-D (CHDIR), Command-Option-F
(Search in Folders).

The old WinEd Control-letter map is not used. Control-F is Find, not
replace. Control-W closes the file. Control-G is Find Next.

Classes
-------

WINED64 is a :CLASS named WINED-EDITOR. The method shape matches
Win32Forth (:CLASS, <SUPER, :M, ;M, ;CLASS, START:). The system underneath
does not. Read Classes/README.txt. The differences that matter here:

  Names are stored in uppercase.
  A selector exists only after some :M creates it.
  INT is one cell, not 32 bits.
  There is no WM: and no Windows device context.
  64Forth EVALUATE does not return to its caller.
  DO / ?DO inside a DOES> word can fault, so the class file avoids that.

START: does not open a second window. The text is drawn with GRAPHICS
words (COLOR8, AT, EMIT, PREFRESH). Classes/oop.fth WINDOW is a separate
Mac window. That window can report its content size with SIZE: and can
report a resize with ?RESIZE:. It is not the editor surface.

Color
-----

WINED.COL is the WinEd keyword file. The first number is the action and
the second is the color. Source names ending in .F, .FTH, .FS, or .4TH
are colored. The paper is a COLOR8 index. Dark paper (index below 8)
gets a white glyph. Light paper gets a black glyph. Ordinary text is
white paper.

What was not brought across
---------------------------

Printing, the registry, the toolbar, HTML browse, hyper.f, MORE-HTML.F,
custom-keys.F, macros, binary and block mode, multiple fonts, a turnkey
EXE, and WinINet. PAGE.F and OVERSTRIKE.F are the Option-Page and Insert
behavior above, not separate files to load.
