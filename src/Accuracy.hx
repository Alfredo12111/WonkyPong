import Protocol.Snapshot;
import Protocol.Vote;

typedef AccuracyScore = { var id:String; var target:Int; var error:Float; var rank:Int; }
typedef AccuracyReport = {
    var impact:Float; var target:Float; var closest:Array<String>; var scores:Array<AccuracyScore>;
}

class Accuracy {
    public static function measure(state:Snapshot, votes:Array<Vote>):AccuracyReport {
        if(state.vx<=0 || state.x>953) throw "Accuracy needs a shot approaching the chamber.";
        // Unfold the wall bounces, then fold the trajectory into the ball-center bounds.
        var raw=state.y-7+state.vy*(953-state.x)/state.vx;
        var folded=raw-Math.floor(raw/1172)*1172;
        var impact=7+Math.min(folded,1172-folded);
        var target=Game.clamp(impact,60,540);
        var scores:Array<AccuracyScore>=[for(v in votes) {id:v.id,target:v.target,error:Math.abs(v.target-target),rank:0}];
        scores.sort(function(a,b) {
            var order=Reflect.compare(a.error,b.error);
            return order==0?Reflect.compare(Protocol.ids.indexOf(a.id),Protocol.ids.indexOf(b.id)):order;
        });
        for(i in 0...scores.length)
            scores[i].rank=i>0 && Math.abs(scores[i].error-scores[i-1].error)<0.0000001?scores[i-1].rank:i+1;
        return {impact:impact,target:target,closest:[for(s in scores) if(s.rank==1) s.id],scores:scores};
    }
}
