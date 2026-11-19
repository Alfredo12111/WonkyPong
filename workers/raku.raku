# Raku both proposes a strategy and runs the final majority election.
my @s = 'state.txt'.IO.lines.map(*.Int);
if @*ARGS && @*ARGS[0] eq 'tally' {
    my @ballots = 'ballots.tsv'.IO.lines.map({
        my @p = .split("\t");
        { id => @p[0], target => @p[1].Int, confidence => @p[2].Int,
          direction => (@p[1].Int < @s[4] - 24 ?? 'UP' !! @p[1].Int > @s[4] + 24 ?? 'DOWN' !! 'HOLD') }
    });
    die 'A sitting requires twelve distinct senators' unless @ballots.elems == 12 && @ballots.map(*<id>).unique.elems == 12;
    my @order = <HOLD UP DOWN>;
    my %counts = @order.map({ $_ => @ballots.grep(*<direction> eq $_).elems });
    my %confidence = @order.map({ $_ => @ballots.grep(*<direction> eq $_).map(*<confidence>).sum });
    # Most votes wins; confidence breaks a tie; HOLD wins a remaining exact tie.
    my $winner = @order.sort({ %counts{$^b} <=> %counts{$^a} || %confidence{$^b} <=> %confidence{$^a} || @order.first($^a, :k) <=> @order.first($^b, :k) })[0];
    my @winning = @ballots.grep(*<direction> eq $winner).sort(*<target>);
    my $target = @winning[@winning.elems div 2]<target>;
    $target = @s[4] if $winner eq 'HOLD';
    'bill.txt'.IO.spurt([$target, $winner, %counts<UP>, %counts<HOLD>, %counts<DOWN>, 12].join("\n") ~ "\n");
} else {
    my $time = @s[2] > 0 ?? (953 - @s[0]) / @s[2] !! 0;
    my $z = (@s[1] - 7 + @s[3] * $time) % 1172;
    my $intercept = 7 + ($z <= 586 ?? $z !! 1172 - $z);
    my $target = (($intercept * 0.85 + @s[4] * 0.15).round max 60) min 540;
    'raku.vote'.IO.spurt("$target\n86\nPredict the bounce, then leave room for a reasonable amendment.\n");
}
