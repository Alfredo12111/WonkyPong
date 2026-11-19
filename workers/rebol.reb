REBOL [Title: "Pongress / Rebol, the pragmatist"]
; Parse only numeric data, never evaluate a request as a program.
parts: split trim read/string %state.txt newline
y: to integer! pick parts 2
vy: to integer! pick parts 4
paddle: to integer! pick parts 5
target: to integer! ((y * 3 + paddle) / 4 + (vy / 5))
target: max 60 min 540 target
write %rebol.vote rejoin [target newline 62 newline "Track the ball we have, not the ball we wish we had." newline]
quit
