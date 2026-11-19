import Protocol.Snapshot;
class Game {
    public var x:Float=500; public var y:Float=300;
    public var vx:Float=310; public var vy:Float=135;
    public var player:Float=300; public var playerTarget:Float=300;
    public var ai:Float=300; public var aiTarget:Float=300;
    public var arrivalY:Float=300; public var arrivalPaddle:Float=300;
    public var human:Int=0; public var senate:Int=0; public var rally:Int=0;
    public var bestRally:Int=0; public var seed:Int=0;
    public var active:Bool=false;
    public var flight:Int=0;
    public var paused:Bool=false; public var finished:Bool=false;
    public var onVote:Void->Void=function() {};
    public var onPoint:Bool->Void=function(_) {};
    public var onHit:Void->Void=function() {};
    public function new() {}
    public static inline function clamp(n:Float,low:Float,high:Float):Float return Math.max(low,Math.min(high,n));
    public function reset() {
        human=0; senate=0; rally=0; bestRally=0; player=300; playerTarget=300; ai=300; aiTarget=300;
        active=true; paused=false; finished=false; seed=Std.random(1000000); serve(true);
    }
    public function serve(toSenate:Bool) {
        flight++;
        x=500; y=300; rally=0;
        vx=toSenate ? 310 : -310;
        vy=(seed%2==0 ? 1 : -1)*(110+seed%90);
        seed=(seed+137)%1000000;
        if(toSenate) onVote();
    }
    public function approaching():Bool return active && !finished && vx>0 && x<953;
    public function approve(target:Int, forFlight:Int):Bool {
        if(forFlight!=flight || !approaching()) return false;
        aiTarget=clamp(target,60,540); return true;
    }
    public function snapshot():Snapshot return {
        x:Std.int(clamp(x,0,1000)), y:Std.int(clamp(y,7,593)), vx:Std.int(vx), vy:Std.int(vy),
        ai:Std.int(ai), player:Std.int(player), rally:rally, human:human, senate:senate, seed:seed
    };
    public function step(dt:Float) {
        if(!active || paused || finished) return;
        dt=clamp(dt,0,0.025);
        player+=clamp(playerTarget-player,-700*dt,700*dt);
        ai+=clamp(aiTarget-ai,-270*dt,270*dt);
        player=clamp(player,60,540); ai=clamp(ai,60,540);
        var oldX=x;
        x+=vx*dt; y+=vy*dt;
        if(y<7) { y=14-y; vy=Math.abs(vy); onHit(); }
        if(y>593) { y=1186-y; vy=-Math.abs(vy); onHit(); }
        if(vx<0 && oldX>=47 && x<=47 && Math.abs(y-player)<=67) {
            x=47; bounce(player,true); flight++; onVote();
        }
        if(vx>0 && oldX<=953 && x>=953) {
            arrivalY=y; arrivalPaddle=ai;
            if(Math.abs(y-ai)<=67) { x=953; bounce(ai,false); }
        }
        if(x < -12 || x>1012) {
            var won=x>1000;
            if(won) human++ else senate++;
            onPoint(won);
            if(human>=7 || senate>=7) { finished=true; active=false; }
            else serve(!won);
        }
    }
    function bounce(paddle:Float,right:Bool) {
        rally++; bestRally=Std.int(Math.max(bestRally,rally));
        var speed=Math.min(520,310+rally*15);
        var offset=clamp((y-paddle)/60,-1,1);
        vx=(right?1:-1)*speed; vy=offset*310;
        if(Math.abs(vy)<55) vy=vy<0?-55:55;
        onHit();
    }
}
