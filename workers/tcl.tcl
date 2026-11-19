set f [open state.txt r]
set s [split [string trim [read $f]] \n]
close $f
lassign $s x y vx vy paddle player rally human senate seed
if {$vx > 0} {
    set t [expr {(953.0-$x)/$vx}]
    set raw [expr {$y-7+$vy*$t}]
    set folded [expr {$raw-floor($raw/1172)*1172}]
    set hit [expr {7+min($folded,1172-$folded)}]
} else {set hit 300}
set target [expr {int(max(60,min(540,0.8*$hit+60)))}]
set f [open tcl.vote w]
puts $f "$target\n75\nTake the rebound estimate and negotiate it toward the center."
close $f
