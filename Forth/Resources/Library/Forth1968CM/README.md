# Forth-1968

**Public domain.**

Charles H. Moore's original Forth, written in 1968 for the IBM 1130. The assembler and the 1130 simulator are written in Forth. The 1968 kernel and the Forth deck are the same files as in Forth-1968-CM.

The simulator uses the EditForth console. Printer output is `TYPE`. The keyboard is `KEY`.

## Run it

```text
FROMLIB FLOAD Forth1968CM/main.fth
FORTH-1968
```

The console prints the assembly banner, the first disk record, and `HI THERE`. That session owns the console until Restart. Type each line. A paste does not reach the 1130 keyboard.

Names are four characters. The machine folds them to upper case. Space or Return ends a word. `$` prints `OK`. Restart ends the session.

## Typing

A dictionary name is four characters. `CONSOLE` is stored as `CONS`. When two words share those four letters, the later one runs. `CONSOLE` is later than `CONSTANT`, so `CONS` is `CONSOLE`.

`$` is an ordinary word. It is defined as `'OK' REPLY`, and it prints `OK`. The console shows the character you typed, and the 1130 prints it again, so the word can appear twice.

```text
$
'HELLO' REPLY
WARN
```

`WARN` replies `NO SUCH FILE`. Definitions begin with `.` and end with `,`:

```text
. HI 'HELLO' REPLY ,
```

`.` then `HI` needs a space. `.HI` is the word `.` followed by `HI`.

Words that do not print: `DUP` `DROP` `SWAP` `RAISE` `MINUS` `+` `-` `*` `/` `AND` `VALUE`. Type `DUP`, not `DUPLICATE`.

`FILL` reads another line from the keyboard. An unknown word is echoed and does not print an error.

## Files

```text
Library/Forth1968CM/
    main.fth              assemble, check, run
    Assembler.fth         IBM 1130 assembler
    Machine.fth           1130 CPU, disk, Selectric, keyboard
    Resources/
        FORTH.asm         kernel source
        FO.FO             Forth deck
        FORTH-1968-CM.pdf the scan
        TRANSCRIPTION.txt
        listing/          assembler listing pages
```

`main.fth` checks the assembled kernel against the listing, packs `FO.FO` as the disk, and starts at the real entry point. The 1968 program then compiles and runs itself.
