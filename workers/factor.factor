USING: io.encodings.utf8 io.files kernel locals math math.functions
math.parser sequences splitting strings ;
IN: pongress
:: vote ( -- )
    "state.txt" utf8 file-lines [ string>number ] map :> s
    0 s nth :> x
    1 s nth :> y
    2 s nth :> vx
    3 s nth :> vy
    4 s nth :> paddle
    vx 0 > [ 953 x - vx / ] [ 0 ] if :> time
    y 7 - vy time * + :> raw
    raw raw 1172 / floor 1172 * - :> folded
    folded 1172 folded - min 7 + :> hit
    hit 0.75 * paddle 0.25 * + 60 max 540 min floor >integer :> target
    target number>string "\n80\nCompose a measured response. Wild swings do not compose.\n" append
    "factor.vote" utf8 set-file-contents ;
vote
