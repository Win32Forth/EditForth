\\ GCLOCK.SEQ  A simple Graphic Clock program  by Tom Zimmer & Robert Smith

  Simple graphic clock program, runs in 640x350 mode.

        .options /opt /noinit /tailopton

 **********************************************************************

 The SINTBL below was defined by using the following program using F-PC
 and Robert Smiths FFLOAT floating point package to generate the values
 which were redirected to a disk file using the ">B" F-PC operator to
 create BROWSE.PRN from the displayed output of this program.
 BROWSE.PRN was then edited into the table you see here, giving an array
 of absolute screen offsets for coordinates to draw the clock hands.

 **********************************************************************

        require ffloat    \ load the floating point package
        floats          \ allow automatic floating point number conversion
        degrees         \ make FSIN word in degrees

        : makesin       ( -- )
                        462 0
                        do      cr i 0 float fsin 240.0 f* int d.
                                100 ms
                                ?keypause
                     6 +loop    ;

 **********************************************************************

{

only forth also graphics
\ require graph.fth

create sintbl
          0 ,    25 ,    49 ,    74 ,    97 ,   120 ,   141 ,   160 ,
        178 ,   194 ,   207 ,   219 ,   228 ,   234 ,   238 ,   240 ,
        238 ,   234 ,   228 ,   219 ,   207 ,   194 ,   178 ,   160 ,
        141 ,   119 ,    97 ,    74 ,    49 ,    25 ,     0 ,   -25 ,
        -49 ,   -74 ,   -97 ,  -120 ,  -141 ,  -160 ,  -178 ,  -194 ,
       -207 ,  -219 ,  -228 ,  -234 ,  -238 ,  -240 ,  -238 ,  -234 ,
       -228 ,  -219 ,  -207 ,  -194 ,  -178 ,  -160 ,  -141 ,  -119 ,
        -97 ,   -74 ,   -49 ,   -25 ,     0 ,    25 ,    49 ,    74 ,
         97 ,   120 ,   141 ,   160 ,   178 ,   194 ,   207 ,   219 ,
        228 ,   234 ,   238 ,   240 ,   238 ,

: graph_bye     ( -- )          \ cleanup stuff when we are all done
cr ." GCLOCK.COM is a public domain example program by Tom Zimmer and Robert Smith."
cr              bye ;

-1 value last-hour
-1 value last-minute
-1 value last-hour-minute
-1 value last-second

 0 value this-hour
 0 value this-minute
 0 value this-second

320 constant center-x
175 value    center-y
240 value    scale-y

0 value oblong
0 value oblong2

0 value SEED1
0 value SEED2
0 value SEED3

: (RANDOMIZE)   ( -- u )
            	  MS@ ;

: RANDOMIZE     ( -- )
                (RANDOMIZE)        TO SEED1
                (RANDOMIZE) 2* 1-  TO SEED2
                (RANDOMIZE) 2/ 1+  TO SEED3 ;

: RND           ( n1 -- n2 )
                1 max
                SEED1 177 /MOD  2*    SWAP  171 *  SWAP  - DUP  TO SEED1
                SEED2 176 /MOD  35 *  SWAP  172 *  SWAP  - DUP  TO SEED2
                SEED3 178 /MOD  63 *  SWAP  170 *  SWAP  - DUP  TO SEED3
                +  + SWAP  MOD  ;

: xy-scale      ( 6deg scale -- x1 y1 )
                >r
                dup       2* sintbl + @ dup r@           240 */
                swap dup 1 and oblong2 rot 2 and if negate then
                ( negate ) * +        center-x +
                swap 15 + 2* sintbl + @ dup r>       scale-y */
                swap dup 1 and oblong2 rot 2 and if negate then
                           * + negate center-y + ;

: .sec          ( n1 -- )
                >r
                center-x center-y  r@    220 xy-scale line
                r@ 1- 020 xy-scale r@    220 xy-scale line
                r@ 1+ 020 xy-scale r@    220 xy-scale line
                center-x center-y  r@ 1- 020 xy-scale line
                center-x center-y  r@ 1+ 020 xy-scale line
                r> drop ;

: .min          ( n1 -- )
                >r
                center-x center-y  r@    180 xy-scale line
                r@ 1- 100 xy-scale r@    180 xy-scale line
                r@ 1+ 100 xy-scale r@    180 xy-scale line
                center-x center-y  r@ 1- 100 xy-scale line
                center-x center-y  r@ 1+ 100 xy-scale line
                r> drop ;

: .hr           ( n1 -- )
                >r
                center-x center-y   r@     120 xy-scale line
                r@ 2 - 060 xy-scale r@     120 xy-scale line
                r@ 2 + 060 xy-scale r@     120 xy-scale line
                center-x center-y   r@ 2 - 060 xy-scale line
                center-x center-y   r@ 2 + 060 xy-scale line
                r> drop ;

: .second       ( -- )          \ draw second display
                black color !
                last-second 60 mod .sec this-second TO last-second
                white color !
                this-second 60 mod .sec ;

: .minute       ( -- )          \ draw minute display
                black color !
                last-minute 60 mod .min this-minute TO last-minute
                ltgreen color !
                this-minute 60 mod .min ;

: .hour         ( -- )          \ draw hour  display
                black color !
                last-hour 5 * last-hour-minute 12 /   + 60 mod .hr
                this-hour   TO last-hour
                this-minute TO last-hour-minute
                ltblue color !
                this-hour 5 * this-minute      12 /   + 60 mod .hr ;

: ?second       ( -- f )        \ f = true if second has changed.
                gettime  256 / >r  256 /mod swap  r>
                dup last-second <>
                if      TO this-second
                        TO this-minute
                        TO this-hour
                        true
                else    3drop false
                then    ;

: init-vars     ( -- )
                ?second drop            \ to initialize LAST-SECOND
                this-second TO last-second
                this-minute TO last-minute
                this-minute TO last-hour-minute
                this-hour   TO last-hour ;

: .hms          ( -- )
                .second         \ draw second
                .minute         \ draw minute
                .hour           \ draw hour
                show-circle ;   \ draw the circles

: new_clock     ( -- )          \ draw a new clock, of random oblong amount
                640x350x16                      \ set graphics mode
                .clock-info
                oblong rnd !> oblong2
                show-border ;

: show-time     ( -- )          \ show the time if it has changed
                ?second                         \ if second changed
                if      this-second 5 mod 0=    \ if on a 5 second marker
                        oblong 1 > and          \ and oblong is above 1
                        if      new_clock       \ redisplay clock border
                        then
                        .hms                    \ and then the time
                then    ;

 0 value ccolor
16 value cdiam

: show-circle   ( -- )
                ccolor 1+ ccolor
                ccolor color !
                60 0
                do      i    cdiam xy-scale cplot
                loop    5 cdiam + TO cdiam
                cdiam 210 > if 16 TO cdiam then ;

: show-border   ( -- )
                60 0
                do      white  color !
                        i 239 xy-scale i 1+ 239 xy-scale line
                        i 228 xy-scale i 1+ 228 xy-scale line
                        i 5 mod
                        if      ltcyan color !           \ 1 second markers
                                i    228 xy-scale i    239 xy-scale line
                        else    yellow color !           \ 5 second markers
                                i    220 xy-scale i    239 xy-scale line
                        then
                        key? IF leave THEN
                loop    ;

: .clock-info   ( -- )
                ltgray >fg black >bg
                53  0 g-at ." Tom & Bob's Graphic Clock"
                53  1 g-at ."     Press "
                white  >fg green  >bg  ."  ESC "  ltgray >fg black >bg
                           ."  to QUIT"
                00 24 g-at ." Modify clock shape = "
                ltblue >fg yellow >bg ."  Enter " ltgray >fg black >bg
                53 24 g-at ." Clear and redraw = "
                yellow >fg cyan   >bg ."  Space " ltgray >fg black >bg
                ;

: do-clock      ( -- )          \ while no key pressed, show the time
                show-border
                show-circle             \ display the circle
                init-vars               \ then initialize variable
                .hms                    \ show initial time
                0
        begin   dup 13 =                \ CR key
                if      i oblong 1+ oblong
                        oblong TO oblong2
                        show-border
                then
                bl =                    \ space bar
                if      new_clock
                then
                begin   key? 0=         \ while nobody has pressed a key
                while   show-time       \ just keep showing the current time
                        show-circle
                repeat  key
                        dup  13 <>
                        over bl <> and
        until   drop ;

: tcom_init     ( -- )
                DECIMAL ;                       \ always select decimal

: main          ( -- )          \ a simple drawing program
                tcom_init                       \ init I/O
                randomize                       \ init random number generator
                ?vmode 7 = abort" Sorry, EGA/VGA Color required"
                640x350x16                      \ set graphics mode
                vdots 2/ 1- !> center-y         \ calibrate screen center
                240 240 center-y */ !> scale-y  \ calibrate aspect ratio
                white color !                   \ default color=white
                .clock-info
                do-clock                        \ show the clock
                 graph_bye                       \ and terminate the program
                ;


