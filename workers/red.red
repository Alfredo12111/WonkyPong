Red [Title: "WonkyPong / Red, the risk caucus"]
parts: split trim read %state.txt newline
x: to float! pick parts 1
y: to float! pick parts 2
vx: to float! pick parts 3
vy: to float! pick parts 4
seed: to integer! pick parts 10
flight: either vx > 0.0 [(953.0 - x) / vx] [0.0]
z: y - 7.0 + (vy * flight)
while [z < 0.0] [z: z + 1172.0]
while [z >= 1172.0] [z: z - 1172.0]
if z > 586.0 [z: 1172.0 - z]
offset: either even? seed [38] [-38]
target: max 60 min 540 to integer! (z + 7.0 + offset)
write %red.vote rejoin [target newline 72 newline "Aim off-center. A boring return is a policy failure." newline]
quit
