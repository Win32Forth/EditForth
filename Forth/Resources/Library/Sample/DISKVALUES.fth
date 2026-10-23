\ DISKVALUES.fth — file-backed values (Jos Ven). EditForth file words.
\ A diskvalue lives in values.dat in the current directory. The dictionary
\ holds only the file offset, so the value survives FORGET / ANEW.
\ The slot is the order the names are defined. Reordering them mixes values.
\ Do not use a diskvalue for data that changes constantly.
\
\ Load-time demo. First run prints: 0 79 3 42
\ A later INCLUDE prints the stored value first (3 79 3 42).

[UNDEFINED] HIDDEN [IF] VOCABULARY HIDDEN [THEN]

HIDDEN DEFINITIONS

$400 VALUE /valFile                          \ bytes in values.dat
0 VALUE >valPos                              \ next free offset
0 VALUE valHndl                              \ 0 = file closed
$D15CDA7A CONSTANT DISK-MAGIC                \ marks a diskvalue body

VARIABLE valCell                             \ one-cell file buffer

: ClosevalFile ( -- )
  valHndl ?DUP IF CLOSE-FILE DROP THEN
  0 TO valHndl ;

: allotvalue ( n -- )                        \ ( n -- ) reserve n bytes, compile offset
  >valPos DUP , + TO >valPos ;

: >diskvalue ( pos -- )
  S>D valHndl REPOSITION-FILE THROW ;

CREATE valFile$  S" values.dat" DUP 1+ ALLOT  valFile$ PLACE

: CreatevalFile ( -- fileid )
  valFile$ COUNT R/W CREATE-FILE THROW TO valHndl
  /valFile 1- >diskvalue
  S" x" valHndl WRITE-FILE THROW
  ClosevalFile
  valFile$ COUNT R/W OPEN-FILE THROW ;

: OpenvalFile ( -- )
  valHndl IF EXIT THEN
  valFile$ COUNT R/W OPEN-FILE ?DUP IF
    DROP                                     \ failed open still returns a fileid
    CreatevalFile
  THEN
  TO valHndl ;

: val@ ( -- x )
  OpenvalFile
  valCell CELL valHndl READ-FILE THROW DROP
  valCell @ ;

\ ( x xt -- ) store x at the diskvalue's offset and commit.
: (val!) ( x xt -- )
  >BODY CELL+ @ >R
  valCell !
  OpenvalFile
  R> >diskvalue
  valCell CELL valHndl WRITE-FILE THROW
  ClosevalFile ;

: DISK? ( xt -- flag )
  >BODY @ DISK-MAGIC = ;

FORTH DEFINITIONS ALSO HIDDEN

: diskvalue ( "name" -- )                    \ runtime: ( -- x )
  CREATE DISK-MAGIC , CELL allotvalue
  DOES> CELL+ @ >R OpenvalFile R> >diskvalue val@ ;

\ ' is not immediate, and diskto is. ' therefore parses the next name
\ when diskto runs, both at the prompt and while compiling a caller.
: diskto ( x "name" -- )
  '
  STATE @ IF
    POSTPONE LITERAL POSTPONE (val!)
  ELSE
    (val!)
  THEN
; IMMEDIATE

\ Same TO as the kernel, plus diskvalues. Forgotten with this module.
' TO VALUE (FORTH-TO)

: TO ( x "name" -- )
  >IN @ >R
  ' DUP DISK? IF
    R> DROP
    STATE @ IF
      POSTPONE LITERAL POSTPONE (val!)
    ELSE
      (val!)
    THEN
  ELSE
    DROP
    R> >IN !
    (FORTH-TO) EXECUTE
  THEN
; IMMEDIATE

PREVIOUS

\ --- demo (runs at load) ---

diskvalue test0
diskvalue test
0 VALUE y

: t1 ( -- )  42 TO y ;
: t2 ( -- )  3 TO test ;

test .                                       \ previous value, or 0
79 diskto test
test .                                       \ 79
t2 test .                                    \ 3
t1 y .                                       \ 42
