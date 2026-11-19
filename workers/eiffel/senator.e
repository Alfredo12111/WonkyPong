class SENATOR
create make
feature
    make
        local f, report: PLAIN_TEXT_FILE; x,y,vx,vy,paddle,target: INTEGER; raw, folded: REAL_64
        do
            create f.make_open_read ("state.txt")
            f.read_line; x := f.last_string.to_integer
            f.read_line; y := f.last_string.to_integer
            f.read_line; vx := f.last_string.to_integer
            f.read_line; vy := f.last_string.to_integer
            f.read_line; paddle := f.last_string.to_integer
            f.close
            if vx > 0 then raw := y - 7 + vy * ((953 - x) / vx) else raw := 293 end
            folded := raw - (raw / 1172).floor_real_64 * 1172
            target := bounded ((7 + folded.min (1172 - folded)).truncated_to_integer)
            create report.make_open_write ("eiffel.vote")
            report.put_string (target.out + "%N93%NA paddle must remain on the court. I have put that in writing.%N")
            report.close
            create f.make_with_name ("bill.txt")
            if f.exists then
                f.open_read; f.read_line; target := f.last_string.to_integer
                f.read_line; f.read_line; x := f.last_string.to_integer
                f.read_line; y := f.last_string.to_integer
                f.read_line; vx := f.last_string.to_integer
                f.read_line; vy := f.last_string.to_integer
                f.close
                certify (target,x+y+vx,vy)
                create report.make_open_write ("certified.txt")
                report.put_string ("PASSED%N" + target.out + "%NAll twelve ballots accounted for; target within court bounds.%N")
                report.close
            end
        end
    bounded (n: INTEGER): INTEGER
        do Result := n.max (60).min (540)
        ensure inside_court: Result >= 60 and Result <= 540
        end
    certify (target, counted, expected: INTEGER)
        require legal_target: target >= 60 and target <= 540
                full_quorum: counted = 12 and expected = 12
        do
        ensure quorum_preserved: counted = expected
        end
end
