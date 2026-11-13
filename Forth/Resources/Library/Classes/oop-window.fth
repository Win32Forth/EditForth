\ Mac window. Host op 1 creates, 2 closes, 3 sets the title.
\ Op 8 returns content width and height packed as w|(h<<16).
\ Op 9 returns true once after the user resizes that window.
\ Not the GRAPHICS App Output window. WINED64 draws on that one.

:CLASS WINDOW <SUPER OBJECT
    INT WID
    INT ORGX
    INT ORGY
    INT WIDT
    INT HITE
    :M CLASSINIT: ( -- )
        CLASSINIT: SUPER
        80 TO ORGX  80 TO ORGY  480 TO WIDT  320 TO HITE
    ;M
    :M START: ( -- )
        ORGX ORGY WIDT HITE 1 (OOP-CALL) TO WID
    ;M
    :M CLOSE: ( -- )
        WID IF  WID 0 0 0 2 (OOP-CALL) DROP  0 TO WID  THEN
    ;M
    :M TITLE: ( c-addr u -- )
        WID 0 3 (OOP-CALL) DROP
    ;M
    :M GETID: ( -- id ) WID ;M
    :M SIZE: ( -- w h )
        WID 0 0 0 8 (OOP-CALL)
        DUP 65535 AND
        SWAP 16 RSHIFT 65535 AND
    ;M
    :M ?RESIZE: ( -- flag )
        WID 0 0 0 9 (OOP-CALL)
    ;M
    :M ~: ( -- ) CLOSE: SELF ;M
;CLASS
