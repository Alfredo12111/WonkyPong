/* Fifty decimal digits, to decide where a rectangle should stand. */
numeric digits 50
x=linein('state.txt'); y=linein('state.txt')
vx=linein('state.txt'); vy=linein('state.txt')
if vx>0 then t=(953-x)/vx
else t=0
z=y-7+vy*t
do while z<0; z=z+1172; end
do while z>=1172; z=z-1172; end
if z>586 then z=1172-z
target=max(60,min(540,trunc(z+7)))
call lineout 'rexx.vote',target
call lineout 'rexx.vote',97
call lineout 'rexx.vote','Fifty decimal digits. No rounding scandal on my watch.'
call lineout 'rexx.vote'
