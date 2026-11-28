# Forth - The Early Years

**Kind:** history, and a reference for where classic Forth words came from.
Not a glossary of EditForth as it is now.

**Modern names:** use the Forth 2012 files in `System/Reference` when
writing a program, or when answering about one. Spellings below are the
names Moore used at the time. `DROP` was once `;`. Store was once `<`.
Those are not the words to type today.

This is a chronology of Chuck Moore's 1991 essay "Forth - The Early
Years." He wrote it for the second History of Programming Languages
conference. It was not accepted. A 1999 note on the HTML copy says the
text was only reformatted, and that sample programs suggested by Phil
Koopman were never added. Much of the same account is in the paper that
was accepted: Elizabeth D. Rather, Donald R. Colburn, and Charles H.
Moore, "The Evolution of Forth," in *History of Programming Languages
II* (Addison-Wesley, 1996).

The essay itself stays at its source:

https://colorforth.github.io/HOPL.html

This file is not Forth source. Do not INCLUDE it.

Moore was the only programmer of the language through the 1960s. It had
no name until 1968. He presents classic Forth as about 150 words, 3 to
8K bytes compiled from 10 to 20 pages, small enough for one person on a
small computer. The setting he describes is a workstation: keyboard,
display, computer, and disk.

## Where each part appeared

- **SAO, 1958.** Interpreter. `WORD` `NUMBER` `INTERPRET` `ABORT`.
- **SLAC, 1961.** Data stack, and the first colon definitions.
- **Freelance / RSI, about 1966.** Keyboard, display, `OK`, and an editor.
- **Mohasco, 1968.** Compiler, return stack, dictionary, disk blocks, and
  a multiprogrammer. The file was named FORTH.
- **NRAO, 1971.** Indirect-threaded code and fixed-point arithmetic. He
  calls the language complete at this point.

## SAO, 1958

After Sputnik (October 1957), Moore was an MIT undergraduate with a job
at the Smithsonian Astrophysical Observatory, working at Harvard. The
work was optical tracking: Moonwatch and Baker-Nunn cameras. He learned
Fortran II for the IBM 704 from a manual John Gaustad loaned him. His
program Ephemeris 4 replaced the desk-calculator predictions he had been
hired to compute. With George Veis he fitted orbits, station positions,
and the shape of the Earth by least squares.

Source was trays of cards, about one compile a day, and a compile took
about half an hour. He wrote a small interpreter so he could change the
drag and Earth-shape terms for each satellite without compiling again.
There was no data stack. The four operations were Fortran statement
numbers, matched on a single character. Input was free-format, which he
preferred to Fortran's fixed columns. `ABORT` ended the run. The cards
were listed as they were read, so the failing line was visible.

At MIT, John McCarthy's LISP course was his introduction to recursion
and to how different a language could be. He records Wil Baden's
comparison: LISP stands to the lambda calculus as Forth stands to
Łukasiewicz postfix. He admired APL's operators and did not adopt that
set as the one he wanted.

## SLAC, 1961

He went to Stanford to study mathematics and worked at the Stanford
Linear Accelerator Center on TRANSPORT, a least-squares program for
steering the two-mile electron beam. Hal Butler led that group. In 1964
he wrote CURVE in Algol on the Burroughs B5500, a general nonlinear
fit. The model was interpreted, and a push-down stack evaluated it.
Input words were six characters, called ATOM after LISP. `DUP`, `DROP`,
and `SWAP` were B5500 instructions.

Words he dates to CURVE:

`+` `-` `*` `NEGATE` `IF` `ELSE` `THEN` `<` `DUP` `DROP` `SWAP` `:` `;`
`VARIABLE` `!` `(` `SIN` `ATAN` `EXP` `LOG`

The spellings were different.

- `NEGATE` was `MINUS`.
- `DROP` was `;`.
- `SWAP` was `.`.
- Store (`!`) was `<`.
- `VARIABLE` was `DECLARE`.
- The definition closer (`;`) was `END`.
- A comment was `COMMENT`, ended by `;`.

`:` came from an Algol label, flipped. Algol wrote `LABEL:`. CURVE wrote
`: LABEL`, so the interpreter did not meet an undefined name first. A
form of `:` was also called `DEFINE`. The colon marked a place in the
input to interpret later. The semicolon stopped that interpretation.

Store appeared with `VARIABLE`. Fetch was automatic, so there was no
`@` yet. The postfix conditional dates from here. Algol was `IF`
expression `THEN` true part `ELSE` false part. CURVE was a stack value,
then `IF`, the true part, `ELSE`, the false part, and `THEN`. A nonzero
stack selects the true part. `THEN` is the one closer, which is why he
kept it. `IF` scanned ahead for `ELSE` or `THEN`. `<` leaves 1 or 0 on
the stack. The transcendentals were library calls.

## Freelance work

He left Stanford in 1965 and programmed in the New York area in Fortran,
Algol, Jovial, PL/I, and assemblers, carrying the card deck and recoding
it for each machine. Terminals made the interpreter useful for a
Teletype.

The new words were `KEY`, `EXPECT`, `EMIT`, `CR`, `SPACE`, `SPACES`,
`DIGIT`, and `TYPE`. `EXPECT` loops on `KEY`. `TYPE` loops on `EMIT`.

For Bob Davis at Realtime Systems, Inc. he supported a Burroughs 5500
time-sharing service, wrote a Fortran-to-Algol translator, and wrote
file editors. The translator is where he decided that spaces between
words matter. Fortran did not require them. Names were still significant
in the first six characters, the width of a 5500 word.

The editor words were `LIST`, `EDIT`, `BEGIN`, `AGAIN`, and `EXIT`.
`BEGIN` … `AGAIN` was spelled `START` … `REPEAT` and bracketed the
commands `T` (`TYPE`), `I` (`INSERT`), `D` (`DELETE`), and `F` (`FIND`).
Those commands later drove the NRAO editor. `FIELD` was already used
the way Mohasco and Forth, Inc. used it in data-base work.

`OK` comes from this period. Each input line is acknowledged when
interpretation finishes. A carriage return has to echo a blank and then
carry `OK`. At RSI, `OK` was printed on the next line. An editor insert
was answered that way. The stack that notation implies was only one
cell deep.

## Mohasco, 1968

In 1968 he joined Mohasco Industries in Amsterdam, New York, a carpet
and furniture company, after Geoff Leach. He rewrote his code in COBOL.
Bob Rayco assigned an IBM 1130 with a 2250 display, to test whether
graphics helped design patterned carpets. The trial ended because the
display had no color, and the 1130 left.

Before it left, the machine was his first real minicomputer shop: a
16-bit CPU, 8K of RAM, a disk, a keyboard, a printer, a card reader and
punch, and Fortran. He ported the interpreter back into Fortran and
added a cross-assembler for the 2250. He reports animated 3-D images
when IBM's own demos were still static 2-D, a Spacewar, and his Algol
chess program rewritten in this language and made much smaller.

The source file was named FORTH, for fourth-generation software. The
operating system allowed five-character file names.

He then turned the 2250 cross-assembler into an 1130 compiler. Words
from that step:

`DO` `LOOP` `UNTIL` `BLOCK` `LOAD` `UPDATE` `FLUSH` `BASE` `CONTEXT`
`STATE` `INTERPRET` `DUMP` `CREATE` `CODE` `;CODE` `CONSTANT` `SMUDGE`
`@` `OVER` `AND` `OR` `NOT` `0=` `0<`

Spellings again differed.

- `LOOP` was `CONTINUE`.
- `UNTIL` was `END`.
- `BLOCK` was `GET`.
- `LOAD` was `READ`.
- `TYPE` was `SEND`.
- `INTERPRET` was `QUERY`.
- `CREATE` was `ENTER`.
- `CODE` was the cent sign, the only use he reports for that character.

The loop index and limit sat on the data stack. `DO` and `CONTINUE`
were meant to echo Fortran.

`BLOCK` kept several buffers. `LOAD` read source from a 1024-byte
block, chosen as a round disk unit. `UPDATE` marked a block dirty.
`FLUSH`, or reuse of its buffer, wrote it back. That is the virtual
memory, and it was hidden inside the store words. `BASE` allowed octal,
decimal, and hex. `CONTEXT` separated editor words from the rest, the
first vocabulary. `STATE` distinguished compiling from interpreting. A
compiled reference stored the count and the first three characters, to
be interpreted later. He briefly allowed a word to end on a special
character, then dropped that. `@` existed in several forms, because a
variable, an array, and a disk block were fetched differently. `DUMP`
was for looking at memory.

The dictionary was new. The interpreter looked up a name in a linked
list, newest entry first. `CREATE` built four fields:

- link to the previous entry
- count and three characters
- code to execute
- parameters

The code field mattered because, once the word was found, the only
overhead was an indirect jump. He credits Stanford compiler writers for
the idea that the count helps tell words apart. `CODE` laid machine
instructions in the parameter field, so a word could be anything the
computer could do. `;CODE` set the code that a new class of words would
run. He describes that as the start of objects. `SMUDGE` hid the
definition being entered, so a search would not recurse into it.

The return stack appeared in the same period. Until then a definition
was not nested, or its return address used the data stack.

The first write-up was an internal Mohasco report by Moore and Leach in
1970. He says it would still read as a Forth paper.

In 1970 Mohasco ordered a Univac 1108 for an order-entry network on
leased lines. He had coded a report generator in Forth and expected to
code the order entry the same way. He ported Forth to a standalone
Burroughs 5500 to show it could host itself. Corporate policy stayed
with COBOL. The compromise was a Forth system on the 1108 that performed
COBOL modules for each transaction. He used third-shift time on a Univac
1107 in Schenectady while the 1108 was pending. Les Sharp was the Univac
liaison. The measure he names is response time, with the system kept
small enough to maintain. A downturn cancelled the 1108. He resigned
first.

The 1108 system was written in assembler. It buffered messages, shared
the CPU across the lines, interpreted the input, called the COBOL
module, and packed records in drum buffers. Words from that system are
`BUFFER`, `PREV`, `OLDEST`, `TASK`, `ACTIVATE`, `GET`, and `RELEASE`.
`BUFFER` skipped a disk read when the block was known to be empty.
`PREV` and `OLDEST` are the variables behind least-recently-used
buffers. `TASK` defines a task at boot. `ACTIVATE` starts it. `GET` and
`RELEASE` lock a shared drum or printer. `PAUSE` is how a task gives up
the CPU. It sits inside I/O, not in the transaction code, and the
scheduler is a round robin that does not lock a task out.

After he gave notice he wrote an unpublished book on how to build Forth
software. It argued for simplicity, and it described indirect-threaded
code. The first implementation of that code was at NRAO, not at
Mohasco. He also worked through the idea of a language that talks about
language: an interpreter hosting an assembler, assembling a compiler,
compiling the interpreter. He decided the term meta-language did not
help. The name meta-compile, for recompiling Forth, stayed.

## NRAO, 1971

George Conant, who had known him at the Smithsonian and liked Ephemeris
4, hired him at the National Radio Astronomy Observatory. He worked in
Charlottesville and, in summer, in Tucson when the 36-foot millimeter
telescope on Kitt Peak was down for maintenance. The job was a
Honeywell 316 controlling a new filter bank, with 9-track tape and a
Tektronix storage-tube terminal. NRAO was a Fortran shop. Other
programmers wanted languages of their own. He had begun to call Forth a
language, and Conant was not pleased. Moore grants the point that an
organization has to pick one language.

He wrote Forth in assembler on an IBM 360/50, cross-compiled it to the
316, then recompiled it on the 316. The application had a continuum mode
and a spectral-line mode. On the spectral-line side he displayed spectra
as they arrived and fitted line shapes by least squares. Ned Conklin ran
the Tucson site. The system was used to find and map interstellar
molecules. Elizabeth (Bess) Rather was hired to learn it on site and to
explain and document it, with little help from him. The next year he
reprogrammed a DDP-116 for telescope pointing. The year after that, he
and Rather replaced the 116 and the 316 with a DEC PDP-11.

Indirect-threaded code is the change he credits for the rest. Instead of
storing the text of a definition and interpreting it again, the compiler
stored the address of each word. On the PDP-11 a reference was two
bytes. The address interpreter was a two-instruction macro. He later
heard that DEC had used direct-threaded code in a compiler. His PDP-11
form was:

```
: NEXT   IP )+ W MOV  W )+ ) JMP ;
```

He says that at this point he could write faster, and the result was
smaller, more reliable, and portable. He recoded the pointing program
for the 300-foot telescope at Green Bank, programmed the HP
minicomputer that was starting VLBI, and on a ModComp computed Fourier
transforms for interferometry and a pulsar search on 64K points. He
reports that a complex multiply on the 360 was 20 percent faster in
Forth than in assembler.

NRAO discussed patenting Forth with a consulting firm that looked for
spin-offs. Software patents were unsettled and might have reached the
Supreme Court, so NRAO did not file. The rights went back to him. He
writes that ideas should not be patentable, and that Forth spread
because it was public.

Threaded code changed `DO`, `LOOP`, `IF`, `THEN`, and the other
structure words. During compilation their addresses sit on the data
stack. Each port gained a postfix assembler: opcodes and address
arithmetic on the data stack, structure words for branches, and the
manufacturer's mnemonics defined as word classes with `;CODE`. He says
that assembler could be an afternoon's work. The `NEXT` macro above is
his example.

Fixed-point operators he singles out are `M*`, `*/`, `/MOD`, `SQRT`,
`SIN.COS`, `ATAN`, `EXP`, and `LOG`.

- `M*` multiplies two 16-bit numbers to a 32-bit product.
- `*/` divides that product. That is how he did rational arithmetic.
- `/MOD` returns quotient and remainder, used to find a record in a file.
- `SQRT` takes 32 bits and returns 16.
- `SIN.COS` returns both values, for vectors and for an FFT.
- `ATAN` is the inverse and does not have a quadrant ambiguity.
- `EXP` and `LOG` are base 2.

Fraction bits were 14 or 30 for trigonometry and 10 for logarithms. He
treats fixed point as the characteristic arithmetic, because it was
simpler, faster, and more accurate than the floating point of that
time. Hardware or software floating point was still easy to add. He
credits John F. Hart's *Computer Approximations* for tables he could
use without being stuck with a vendor library.

`DOES>` appeared here, spelled `;:`. Like `;CODE`, it defines a class.
The behavior is a Forth definition run when the child word executes. He
used it for opcodes and says it was hard to invent.

He did not persuade Charlottesville to let him program the VLA. His
summary of adoption is that in a group about a quarter of the people
like Forth and about a quarter hate it, and that the arguments do not
meet in the middle. The people who wanted it formed Forth, Inc. The
essay stops there. His biographical page on the same site dates that
company to 1973.

## What he leaves unwritten

He sketches a later story and does not tell it: Forth, Inc. competing
with IBM on a French banking system. He says he still considers Forth
the best language he knows, including in artificial intelligence, and
that he was by then exploring a machine in which the software and the
silicon are one design.

## Names he lists

These are the words the essay stops to name, grouped as he grouped them.
Dates above say when the idea arrived. Some names in this list are the
later spelling, not the 1964 or 1968 spelling.

Interpreter: `WORD` `NUMBER` `INTERPRET` `ABORT` `HASH` `FIND` `'`
`FORGET` `BASE` `OCTAL` `DECIMAL` `HEX` `LOAD` `EXIT` `EXECUTE` `(`.

Terminal: `KEY` `EXPECT` `EMIT` `CR` `SPACE` `SPACES` `DIGIT` `TYPE`
`DUMP`.

Data stack: `DUP` `DROP` `SWAP` `OVER` `+` `-` `*` `/` `MOD` `NEGATE`
`ABS` `MAX` `MIN` `AND` `OR` `XOR` `NOT` `0<` `0=` `=` `@` `!` `+!`
`C@` `C!` `SQRT` `SIN.COS` `ATAN` `EXP` `LOG`.

Return stack: `:` `;` `PUSH` `POP` `I`. He lists `PUSH` and `POP` for
the return stack. Later Forth standardized on `>R` and `R>`.

Disk: `BLOCK` `UPDATE` `FLUSH` `BUFFER` `PREV` `OLDEST`.

Compiler: `CREATE` `ALLOT` `,` `SMUDGE` `VARIABLE` `CONSTANT` `[` `]`
`LITERAL` `."` `COMPILE` `BEGIN` `UNTIL` `AGAIN` `WHILE` `REPEAT` `DO`
`LOOP` `+LOOP` `IF` `ELSE` `THEN`.

## Early spelling

- `NEGATE` was `MINUS` (CURVE, 1964).
- `DROP` was `;`.
- `SWAP` was `.`.
- `!` was `<`.
- `VARIABLE` was `DECLARE`.
- `;` was `END`.
- `(` was `COMMENT`, closed by `;`.
- `LOOP` was `CONTINUE` (Mohasco, 1968).
- `UNTIL` was `END`.
- `BLOCK` was `GET`.
- `LOAD` was `READ`.
- `TYPE` was `SEND`.
- `INTERPRET` was `QUERY`.
- `CREATE` was `ENTER`.
- `CODE` was the cent sign.
- `BEGIN` … `AGAIN` was `START` … `REPEAT` (RSI editor).
- `DOES>` was `;:` (NRAO, 1971).

## References he gives

- Draft Proposed ANS Forth, X3.215-199x (1991). Global Engineering
  Documents, Irvine.
- Leo Brodie, *Starting FORTH*, Prentice-Hall, 1981. ISBN 0-13-842930-8.
  He calls this the book that still best shows the flavor of Forth.
- John F. Hart and others, *Computer Approximations*, Krieger, 1968.
  Second edition 1978. ISBN 0-88275-642-7. The essay cites 1978 in the
  text and 1968 in the reference list.
- Thea Martin, *A Bibliography of Forth References*, 3rd ed. Institute
  for Applied Forth Research, 1987. ISBN 0-914593-07-2. Subject and
  author index of the Journal of Forth Application and Research.
- Charles H. Moore and Don A. Lautman, predictions for photographic
  tracking stations, APO Ephemeris 4. SAO Special Report No. 11, March
  1958.
- Charles H. Moore and Geoffrey C. Leach, "FORTH - A Language for
  Interactive Computing." Mohasco Industries, internal report, 1970.
- Charles H. Moore and Elizabeth D. Rather, the FORTH program for
  spectral-line observing on NRAO's 36-foot telescope. *Astronomy and
  Astrophysics Supplement Series*, vol. 15, no. 3, June 1974. The
  symposium was in Charlottesville, 13–15 November 1972. The essay's
  running text cites this as Moore 1973.
- Charles H. Moore, "The evolution of FORTH, an unusual language."
  *Byte*, August 1980.
- Elizabeth D. Rather, Donald R. Colburn, and Charles H. Moore, "The
  Evolution of Forth." *History of Programming Languages II*,
  Addison-Wesley, 1996. ISBN 0-201-89502-1. The essay cites the
  conference paper as Rather 1993.
- George Veis and C. H. Moore, SAO differential orbit improvement
  program. JPL tracking and orbit seminar, 23–26 February 1960.

## In this tree

The same text is in both of these places:

- `Forth/Resources/Docs/Forth-Early-Years.md`, and the same file under
  `~/Documents/EditForth/Docs/`
- `Forth/Resources/System/Reference/Forth-Early-Years.md`, and the same
  file under `~/Documents/EditForth/System/Reference/`

Docs is the reading copy. The file list opens it as a formatted
preview. `System/Reference` is so Ask Forth can find this history when
Library context is on. The banner at the top tells that search not to
treat the old spellings as the words in a modern program.

Source page, from Moore's typescript, as archived with the colorForth
site:

https://colorforth.github.io/HOPL.html

The address he prints on the essay is chipchuck@colorforth.com.
