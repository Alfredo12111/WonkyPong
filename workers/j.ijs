NB. Analytic triangular-wave reflection; input is parsed as numbers, not code.
LF =: 10 { a.
vote =: 3 : 0
  s =. _999&". ;._2 (1!:1 <'state.txt')
  'x y vx vy paddle player rally human senate seed' =. s
  t =. 0
  if. vx > 0 do. t =. (953-x)%vx end.
  z =. 1172 | (y-7) + vy*t
  hit =. 7 + 586 - | z-586
  target =. <. 60 >. 540 <. hit
  ((":target),LF,'98',LF,'The triangular wave has already resolved this debate.',LF) (1!:2) <'j.vote'
  2!:55 (0)
)
vote ''
