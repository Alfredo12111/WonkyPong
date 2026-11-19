# Five nearby trajectories form a tiny uncertainty ensemble.
s ← •ParseFloat¨ •FLines "state.txt"
x‿y‿vx‿vy‿paddle‿player‿rally‿human‿senate‿seed ← s
t ← (vx>0)×(953-x)÷1⌈vx
velocities ← vy+¯12‿¯6‿0‿6‿12
z ← 1172 | (y-7)+velocities×t
hits ← 7+586-|z-586
target ← ⌊60⌈540⌊2⊑∧hits
"bqn.vote" •FLines ⟨•Repr target,"94","Five possible futures. The middle one has my vote."⟩
