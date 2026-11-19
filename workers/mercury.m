:- module mercury.
:- interface.
:- import_module io.
:- pred main(io::di, io::uo) is det.
:- implementation.
:- import_module int, list, string, maybe.
:- type phase ---> approaching ; retreating.
:- func mode(int) = phase.
mode(V) = (if V > 0 then approaching else retreating).
:- func clamp(int) = int.
clamp(N) = int.max(60, int.min(540, N)).
:- func reflect(int) = int.
reflect(N) = 7 + int.min(Z,1172-Z) :- Z = ((N mod 1172) + 1172) mod 1172.
main(!IO) :-
    io.open_input("state.txt", Open, !IO),
    ( Open = error(_), io.set_exit_status(1,!IO)
    ; Open = ok(F), io.read_file_as_string(F, Read,!IO), io.close_input(F,!IO),
      ( Read = error(_, _), io.set_exit_status(1,!IO)
      ; Read = ok(Text),
        ( list.map(string.to_int,string.words(Text),Numbers), Numbers = [X,Y,Vx,Vy,_,_,_,_,_,_] ->
            Phase = mode(Vx),
            ( Phase = approaching, Target = clamp(reflect(Y-7+(Vy*(953-X))//Vx))
            ; Phase = retreating, Target = 300 ),
            io.open_output("mercury.vote", Out,!IO),
            ( Out = ok(O), io.write_string(O,string.int_to_string(Target) ++ "\n90\nAn exhaustive case analysis leaves no room for a filibuster.\n",!IO),io.close_output(O,!IO)
            ; Out = error(_),io.set_exit_status(1,!IO) )
        ; io.set_exit_status(1,!IO) )
      )
    ).
