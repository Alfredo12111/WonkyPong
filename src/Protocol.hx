typedef Snapshot = {
    var x:Int; var y:Int; var vx:Int; var vy:Int; var ai:Int; var player:Int;
    var rally:Int; var human:Int; var senate:Int; var seed:Int;
}
typedef Vote = {
    var id:String; var target:Int; var confidence:Int; var reason:String; var ms:Int;
}
typedef Decision = {
    var target:Int; var direction:String; var up:Int; var hold:Int; var down:Int;
    var ms:Int; var votes:Array<Vote>; var record:String; var certified:Bool;
}
class Protocol {
    public static final ids = ["prolog","raku","tcl","red","j","rebol","mercury","eiffel","bqn","factor","rexx","icon"];
    public static final names = ["Prolog","Raku","Tcl","Red","J","Rebol","Mercury","Eiffel","BQN","Factor","Rexx","Icon"];
    public static final roles = ["The logician","The coalition builder","The negotiator","The risk caucus","The mathematician","The pragmatist","The type theorist","The constitutionalist","The futurist","The composer","The auditor","The skeptic"];
    public static final colors = ["#ef947e","#c29aff","#83d5c0","#f9787f","#b5e873","#d4b98c","#91afe9","#d9dfeb","#a88cf7","#72d4d6","#f1b269","#bf9bb9"];
    public static function validate(d:Dynamic):Snapshot {
        if (d == null) throw "A game snapshot is required.";
        var limits = [
            {name:"x",lo:0,hi:1000}, {name:"y",lo:7,hi:593},
            {name:"vx",lo:-800,hi:800}, {name:"vy",lo:-800,hi:800},
            {name:"ai",lo:60,hi:540}, {name:"player",lo:60,hi:540},
            {name:"rally",lo:0,hi:10000}, {name:"human",lo:0,hi:7},
            {name:"senate",lo:0,hi:7}, {name:"seed",lo:0,hi:1000000}
        ];
        for (limit in limits) {
            var n:Dynamic = Reflect.field(d,limit.name);
            if (!(Std.isOfType(n,Float) || Std.isOfType(n,Int)) || !Math.isFinite(n) ||
                n != Math.floor(n) || n < limit.lo || n > limit.hi) throw "Invalid "+limit.name+".";
        }
        if (d.vx == 0) throw "The ball must have a horizontal direction.";
        return cast d;
    }
    public static function encode(s:Snapshot):String
        return [s.x,s.y,s.vx,s.vy,s.ai,s.player,s.rally,s.human,s.senate,s.seed].join("\n")+"\n";
    public static function direction(target:Float, ai:Float):String
        return target < ai-24 ? "UP" : target > ai+24 ? "DOWN" : "HOLD";
    public static function name(id:String):String return names[ids.indexOf(id)];
}
