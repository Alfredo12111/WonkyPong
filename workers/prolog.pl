:- use_module(library(readutil)).
:- initialization(main, main).
proposal(_, _, Vx, _, _, 300, 70) :- Vx =< 0, !.
proposal(X, Y, Vx, Vy, _, Target, 91) :-
    Time is (953-X)/Vx,
    Raw is Y-7+Vy*Time,
    Fold is Raw-floor(Raw/1172)*1172,
    ( Fold =< 586 -> Hit is Fold+7 ; Hit is 1179-Fold ),
    Target is max(60,min(540,round(Hit))).
main :-
    read_file_to_string('state.txt', Text, []),
    split_string(Text, "\n\r", "\n\r", Lines),
    maplist(number_string, Numbers, Lines),
    Numbers = [X,Y,Vx,Vy,Paddle|_],
    proposal(X,Y,Vx,Vy,Paddle,Target,Confidence),
    setup_call_cleanup(open('prolog.vote',write,S),
      format(S,'~d~n~d~nThe rebound follows from the rules. The motion is admissible.~n',[Target,Confidence]),close(S)).
